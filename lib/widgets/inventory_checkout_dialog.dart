import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/google_sheets_service.dart';

class InventoryCheckoutDialog extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final VoidCallback onClearCart;

  const InventoryCheckoutDialog({
    super.key,
    required this.cartItems,
    required this.onClearCart,
  });

  @override
  State<InventoryCheckoutDialog> createState() => _InventoryCheckoutDialogState();
}

class _InventoryCheckoutDialogState extends State<InventoryCheckoutDialog> {
  File? _capturedImage;
  bool _isSaving = false;
  String? _errorMessage;
  final TextEditingController _takenByController = TextEditingController();

  @override
  void dispose() {
    _takenByController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo != null) {
      setState(() {
        _capturedImage = File(photo.path);
      });
    }
  }

  Future<String?> _uploadImageToCatbox(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
      request.fields['reqtype'] = 'fileupload';
      request.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));
      final response = await request.send();
      if (response.statusCode == 200) {
        return await response.stream.bytesToString();
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }
    return null;
  }

  Future<void> _saveRecord() async {
    if (_takenByController.text.trim().isEmpty) {
      _showError('Please enter who is taking these items.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String imageUrl = 'No Image';
    if (_capturedImage != null) {
      final url = await _uploadImageToCatbox(_capturedImage!);
      if (url != null && url.isNotEmpty) {
        imageUrl = url;
      } else {
        imageUrl = 'Failed to upload image';
      }
    }

    DateTime now = DateTime.now();
    String datePart = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String timePart = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    String takenBy = _takenByController.text.trim();

    bool hasError = false;
    String errorMessage = '';

    for (var item in widget.cartItems) {
      Map<String, dynamic>? rawItem = item['rawItem'] as Map<String, dynamic>?;
      
      String getRawVal(String key) {
        if (rawItem == null) return '';
        for (var entry in rawItem.entries) {
          if (entry.key.trim().toUpperCase() == key.toUpperCase()) {
            return entry.value.toString();
          }
        }
        for (var entry in rawItem.entries) {
          if (entry.key.trim().toUpperCase().contains(key.toUpperCase())) {
            return entry.value.toString();
          }
        }
        return '';
      }

      String getExactKey(String key) {
        if (rawItem == null) return key;
        for (var entry in rawItem.entries) {
          if (entry.key.trim().toUpperCase() == key.toUpperCase()) {
            return entry.key;
          }
        }
        for (var entry in rawItem.entries) {
          if (entry.key.trim().toUpperCase().contains(key.toUpperCase())) {
            return entry.key;
          }
        }
        return key;
      }

      Map<String, String> rowData = {
        'DATE': datePart,
        'TIME': timePart,
        'DEPARTMENT': getRawVal('DEPARTMENT'),
        'CATEGORY': item['category'] ?? getRawVal('CATEGORY'),
        'TAKEN BY': takenBy,
        'DESCRIPTION': item['description'] ?? item['item'] ?? 'Unknown Item',
        'SPECIFICATION': getRawVal('SPECIFICATION'),
        'UOM': getRawVal('UOM'),
        'PERIOD': getRawVal('PERIOD'),
        'STOCK': item['qty']?.toString() ?? '1',
        'PICTURE': imageUrl,
      };

      final error = await GoogleSheetsService.addRow(
        rowData: rowData,
        sheetName: 'STOCK_TAKEN',
      );

      if (error != null) {
        hasError = true;
        errorMessage = error;
        break; // Stop uploading if one fails
      }

      // Now update the original stock in STORE _MATERIAL_STOCK _LIST
      // The exact column name in the sheet might be 'Current Stock', 'Stock', or similar
      String exactStockKey = getExactKey('CURRENT STOCK');
      if (exactStockKey.toUpperCase() == 'CURRENT STOCK' && getRawVal('CURRENT STOCK').isEmpty) {
        exactStockKey = getExactKey('STOCK');
        if (exactStockKey.toUpperCase().contains('MINIMUM')) {
          exactStockKey = 'STOCK';
          if (rawItem != null) {
            for (var entry in rawItem.entries) {
              if (entry.key.trim().toUpperCase() == 'STOCK') {
                exactStockKey = entry.key;
                break;
              }
            }
          }
        }
      }
      
      int currentStock = int.tryParse(getRawVal(exactStockKey)) ?? 0;
      int qtyTaken = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
      int newStock = currentStock - qtyTaken;

      // Identify the exact item using 'Material Name' or fallback to 'DESCRIPTION'
      String identifierKey = getExactKey('MATERIAL NAME');
      String descVal = getRawVal(identifierKey);
      if (descVal.isEmpty) {
        identifierKey = getExactKey('DESCRIPTION');
        descVal = getRawVal(identifierKey);
        if (descVal.isEmpty) descVal = item['description'] ?? item['item'] ?? '';
      }
      
      Map<String, String>? origDataStrMap;
      if (rawItem != null) {
        origDataStrMap = rawItem.map((k, v) => MapEntry(k, v.toString()));
      }

      final updateError = await GoogleSheetsService.editRow(
        ivNo: '', // unused if identifierKey or originalData is provided
        updates: {exactStockKey: newStock.toString()},
        sheetName: 'STORE _MATERIAL_STOCK _LIST',
        identifierKey: identifierKey,
        identifierValue: descVal,
        originalData: origDataStrMap,
      );

      if (updateError != null) {
        hasError = true;
        errorMessage = 'Failed to update stock: $updateError';
        break;
      }
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (hasError) {
        _showError('Failed to save to STOCK_TAKEN: $errorMessage');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items successfully issued with photo verification!')),
        );
        widget.onClearCart();
        Navigator.pop(context, true); // Close dialog and return true
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.shopping_cart_checkout, color: Colors.indigo),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Checkout',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items in Cart:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (widget.cartItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        widget.onClearCart();
                      });
                    },
                    icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.redAccent),
                    label: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.redAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: widget.cartItems.isEmpty 
                  ? const Center(key: ValueKey('empty'), child: Text('Your cart is empty', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                  key: const ValueKey('list'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.cartItems.length,
                itemBuilder: (context, index) {
                  final item = widget.cartItems[index];
                  final maxStock = item['maxStock'] as int? ?? 0;
                  final minStock = item['minStock'] as int? ?? 0;
                  final currentQty = int.tryParse(item['qty'].toString()) ?? 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2, color: Colors.indigo, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['description'] ?? item['item'] ?? 'Unknown Item', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['category'] ?? '', 
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  color: Colors.black87,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    setState(() {
                                      if (currentQty > 1) {
                                        item['qty'] = (currentQty - 1).toString();
                                      } else {
                                        widget.cartItems.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  '$currentQty', 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  color: Colors.black87,
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () {
                                    if (minStock > maxStock) {
                                      _showError('Cannot add more. Stock is below Minimum Stock!');
                                      return;
                                    }
                                    if ((currentQty + 1) > maxStock) {
                                      _showError('Cannot add more. Only $maxStock in stock!');
                                      return;
                                    }
                                    setState(() {
                                      item['qty'] = (currentQty + 1).toString();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            const Text('Taken By:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            TextField(
              controller: _takenByController,
              decoration: InputDecoration(
                hintText: 'Enter the name of the person taking items...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_capturedImage != null) ...[
              const Text('Recipient Photo:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _capturedImage!,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveRecord,
                  icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isSaving ? 'Saving...' : 'Confirm & Save Record', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Photo verification required',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _takePicture,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Take Picture of Recipient', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            if (_capturedImage != null && !_isSaving)
              Center(
                child: TextButton.icon(
                  onPressed: _takePicture,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retake Picture'),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
