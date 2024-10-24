import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery/config/internal_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class ShipmentScreen extends StatefulWidget {
  final int senderId;
  final String senderGPS;
  final int receiverId;
  final String receiverGPS;

  ShipmentScreen(
      this.senderId, this.senderGPS, this.receiverId, this.receiverGPS);

  @override
  _ShipmentScreenState createState() => _ShipmentScreenState();
}

class _ShipmentScreenState extends State<ShipmentScreen> {
  final TextEditingController descriptionController = TextEditingController();
  File? _image;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Shipment')),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade400,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      height: 200,
                      width: double.infinity,
                      child: _image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _image!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.camera_alt,
                                  size: 70,
                                  color: Color.fromARGB(255, 255, 255, 255)),
                            ),
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildDescriptionField(),
                  SizedBox(height: 16),
                  _buildConfirmButton(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                "รายละเอียดของการจัดส่ง",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(5, 5, 1, 1),
              ),
              maxLines: null,
              minLines: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _showConfirmationDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey,
          minimumSize: const Size(double.infinity, 45),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("ยืนยัน",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            SizedBox(width: 10),
            Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final choice = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          actions: [
            TextButton(
              child: Text('Camera'),
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            TextButton(
              child: Text('Gallery'),
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        );
      },
    );

    if (choice != null) {
      final pickedFile = await picker.getImage(source: choice);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _createShipment() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image.')),
      );
      return;
    }

    // ตรวจสอบประเภทของไฟล์รูปภาพ
    final fileExtension = _image!.path.split('.').last.toLowerCase();
    if (!['png', 'jpg', 'jpeg'].contains(fileExtension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('โปรดเลือกไฟล์รูปภาพที่ถูกต้อง (PNG, JPG, JPEG)')),
      );
      return;
    }

    final uri = Uri.parse('$API_ENDPOINT/shipments/shipments');
    final request = http.MultipartRequest('POST', uri);

    // เพิ่มข้อมูลผู้ส่ง ผู้รับ และคำอธิบาย
    request.fields['sender_id'] = widget.senderId.toString();
    request.fields['receiver_id'] = widget.receiverId.toString();
    request.fields['description'] = descriptionController.text;
    request.fields['pickup_location'] = widget.senderGPS;
    request.fields['delivery_location'] = widget.receiverGPS;
    request.fields['status'] = '1'; // สถานะเริ่มต้นเป็น 1 (รอการรับสินค้า)

    // เพิ่มไฟล์รูปภาพ
    var imageFile = await http.MultipartFile.fromPath(
      'image',
      _image!.path,
      contentType: MediaType('image', fileExtension),
    );

    request.files.add(imageFile);

    setState(() {
      _isLoading = true; // ตั้งค่าสถานะกำลังโหลด
    });

    try {
      final response = await request.send();

      if (response.statusCode == 201) {
        final responseData = await response.stream.bytesToString();
        final data = json.decode(responseData);

        // ดึง shipment_id จากข้อมูลที่ได้รับ
        int shipmentId =
            data['shipment_id']; // แก้ไขตรงนี้ให้ตรงกับข้อมูลที่ได้

        // เรียกใช้ฟังก์ชันเพิ่มข้อมูลการจัดส่งลงใน Firestore พร้อมกับ shipment_id
        await _addShipmentToFirestore(shipmentId); // ส่ง shipmentId

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );

        // กลับไปยังหน้าผู้ใช้
        Navigator.pop(context);
      } else {
        final responseData = await response.stream.bytesToString();
        final errorData = json.decode(responseData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['message'])),
        );
      }
    } catch (e) {
      // จัดการข้อผิดพลาดที่เกิดขึ้นในขณะส่งข้อมูล
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งข้อมูล: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false; // ตั้งค่าสถานะไม่กำลังโหลด
      });
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ยืนยันการจัดส่งสินค้า'),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('ยกเลิก',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _createShipment(); // รอให้สร้างการจัดส่งเสร็จ
                  },
                  child: const Text('ยืนยัน',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _addShipmentToFirestore(int shipmentId) async {
    try {
      // สร้างเอกสารใหม่ใน Firestore
      var data = {
        'shipment_id': shipmentId, // บันทึก shipment_id
        'sender_id': widget.senderId, // ควรเป็น number
        'receiver_id': widget.receiverId, // ควรเป็น number
        'description': descriptionController.text,
        'pickup_location': widget.senderGPS,
        'delivery_location': widget.receiverGPS,
        'status': 1, // สถานะเริ่มต้น ควรเป็น number
      };

      // เพิ่มเอกสารลงใน collection 'shipments' โดยใช้ shipment_id เป็น ID ของเอกสาร
      await FirebaseFirestore.instance
          .collection('shipments')
          .doc(shipmentId.toString()) // ใช้ shipment_id เป็น document ID
          .set(data);

      // แสดงข้อความยืนยันเมื่อบันทึกสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('การจัดส่งถูกบันทึกเรียบร้อยแล้ว!')),
      );
    } catch (e) {
      // แสดงข้อความข้อผิดพลาดเมื่อบันทึกไม่สำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e')),
      );
    }
  }
}
