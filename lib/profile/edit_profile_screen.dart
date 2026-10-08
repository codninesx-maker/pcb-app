import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharmacist_profile/admobs/ads_test_banner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pharmacist_profile/image/cloudinary_service.dart';
import 'package:file_picker/file_picker.dart';

import '../dashboard/post/image_reels.dart';

class EditprofileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const EditprofileScreen({super.key, this.userData});

  @override
  State<EditprofileScreen> createState() => _EditprofileScreenState();
}

class _EditprofileScreenState extends State<EditprofileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _gradeController = TextEditingController();
  final _aboutController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hospitalController = TextEditingController(); // Company Location
  final _emailController = TextEditingController();
  final _bmdcController = TextEditingController(); // Company Name
  final _nidController = TextEditingController(); // Job Title
  final _pcbLicenseController = TextEditingController();
  final ImagePickerHelper _imagePickerHelper = ImagePickerHelper();

  String _selectedStatus = "Available";
  final List<String> _statusOptions = ["Available", "Unavailable"];

  bool get _isStudent => _selectedSpecialty == "Student Pharmacy" || _selectedGrade == "Student";
  String get universityLabel => _isStudent ? "University / Institute" : "Company Name";
  String get deptLabel => _isStudent ? "Department" : "Job Title";
  String get batchLabel => _isStudent ? "Batch / Session" : "Company Location";
  String get credentialLabel => _isStudent ? "Student ID / Roll" : "PCB Licence #";

  // Phone visibility state options
  String _phoneVisibility = "Public";
  final List<String> _phoneVisibilityOptions = ["Public", "Private"];

  String? _selectedSpecialty;
  String? _selectedGrade;
  File? _videoFile;

  File? _imageFile;
  File? _coverFile; // Added cover image file state
  bool _isLoading = false;
  bool _isVerifyingPcb = false; // Added PCB verification state

  final _cloudinary = CloudinaryService();
  final _supabase = Supabase.instance.client;

  final List<String> _specialtyOptions = [
    "Teacher University", "Community Pharmacist", "Clinical Pharmacist",
    "Hospital Pharmacist", "Consultant Pharmacist", "Ambulatory Care Pharmacist",
    "Geriatric Pharmacist", "Pediatric Pharmacist", "Oncology Pharmacist",
    "Psychiatric Pharmacist", "Critical Care Pharmacist", "Infectious Diseases Pharmacist",
    "Industrial Pharmacist", "Compounding Pharmacist", "Regulatory Affairs Pharmacist",
    "Pharmacist Researcher", "Drug Information Pharmacist", "Student Pharmacy"
  ];

  final List<String> _gradeOptions = [
    "Grade A",
    "Grade B",
    "Grade C",
    "Grade S"
  ];

  @override
  void initState() {
    super.initState();
    final profile = widget.userData ?? {};

    _nameController.text = profile['name'] ?? "";
    _specialtyController.text = profile['specialization'] ?? "";
    _gradeController.text = profile['grade'] ?? "";
    _aboutController.text = profile['about_profile'] ?? "";
    _bmdcController.text = profile['company_name'] ?? "";
    _nidController.text = profile['company_name'] ?? "";
    _hospitalController.text = profile['job_location'] ?? "";
    _pcbLicenseController.text = profile['pcb_licence'] ?? "";
    _emailController.text = profile['email'] ?? "";
    _phoneController.text = profile['phone'] ?? "";
    _selectedStatus = profile['status'] ?? "Available";

    // Load phone visibility from existing data or default to Public
    _phoneVisibility = profile['phone_visibility'] ?? "Public";
    if (!_phoneVisibilityOptions.contains(_phoneVisibility)) {
      _phoneVisibility = "Public";
    }

    _selectedSpecialty = _specialtyOptions.contains(profile['specialization'])
        ? profile['specialization']
        : null;

    _selectedGrade = _gradeOptions.contains(profile['grade'])
        ? profile['grade']
        : null;
  }

  Future<void> _pickAndValidateMedia({bool isCover = false}) async {
    // ⚠️ Security & Policy Warning Check
    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Media Upload Policy"),
        content: const Text(
          "Strictly prohibited: Nudity, sexually explicit content, adult material, or violence. "
              "All uploads are automatically scanned by AI moderation. Violating accounts will be banned.\n\nDo you wish to proceed?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("I Agree", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    // Show bottom sheet to choose between Gallery or Camera
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCover ? "Select Cover Photo Source" : "Select Profile Picture Source",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
              title: const Text("Choose from Gallery"),
              onTap: () async {
                Navigator.pop(sheetContext);
                final file = await _imagePickerHelper.pickImage(ImageSource.gallery);
                if (file != null) {
                  _validateAndSetFile(file, isCover);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text("Take a Picture"),
              onTap: () async {
                Navigator.pop(sheetContext);
                final file = await _imagePickerHelper.pickImage(ImageSource.camera);
                if (file != null) {
                  _validateAndSetFile(file, isCover);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

// Helper to validate size and update state
  Future<void> _validateAndSetFile(File file, bool isCover) async {
    final fileSize = await file.length();
    if (fileSize > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image size must be less than 5MB.")),
      );
      return;
    }

    setState(() {
      if (isCover) {
        _coverFile = file;
      } else {
        _imageFile = file;
      }
    });
  }

  Future<void> _verifyPcbViaCloudFunction() async {
    bool isStudent = _selectedSpecialty == "Student Pharmacy" || _selectedGrade == "Student";

    if (isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Student profile: Verification bypassed"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty ||
        _gradeController.text.trim().isEmpty ||
        _pcbLicenseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Name, Grade, and PCB Licence")),
      );
      return;
    }

    if (_isVerifyingPcb) return;
    setState(() => _isVerifyingPcb = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verifying credentials against registry...")),
      );

      final response = await _supabase.functions.invoke(
        'verify-pcb',
        body: {
          'name': _nameController.text.trim(),
          'pcb_licence': _pcbLicenseController.text.trim(),
          'is_student': false,
        },
      );

      setState(() => _isVerifyingPcb = false);

      if (response.status == 200) {
        final data = response.data;
        bool isVerified = data['verified'] ?? false;

        if (isVerified) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ Registry match verified successfully!"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("❌ ${data['message'] ?? 'Parameters do not match exact registry records.'}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        throw Exception("Server returned status ${response.status}");
      }
    } catch (e) {
      setState(() => _isVerifyingPcb = false);
      debugPrint("Verification Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveprofile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final profile = widget.userData ?? {};
      String? imageUrl = profile['image_url'];
      String? coverUrl = profile['cover_url'];

      // 1. Handle New Profile Picture Upload & Old Deletion
      if (_imageFile != null) {
        final newImageUrl = await _cloudinary.uploadImage(_imageFile!);
        if (newImageUrl != null) {
          if (imageUrl != null && imageUrl.isNotEmpty) {
            try {
              await _cloudinary.deleteMedia(imageUrl);
            } catch (_) {}
          }
          imageUrl = newImageUrl;
        }
      }

      // 2. Handle New Cover Photo Upload & Old Deletion
      if (_coverFile != null) {
        final newCoverUrl = await _cloudinary.uploadImage(_coverFile!);
        if (newCoverUrl != null) {
          if (coverUrl != null && coverUrl.isNotEmpty) {
            try {
              await _cloudinary.deleteMedia(coverUrl);
            } catch (_) {}
          }
          coverUrl = newCoverUrl;
        }
      }

      final updateData = {
        'name': _nameController.text.trim(),
        'specialization': _selectedSpecialty,
        'grade': _selectedGrade,
        'about_profile': _aboutController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone_visibility': _phoneVisibility,
        'company_name': _bmdcController.text.trim(),
        'job_title': _nidController.text.trim(),
        'job_location': _hospitalController.text.trim(),
        'pcb_licence': _pcbLicenseController.text.trim(),
        'email': _emailController.text.trim(),
        'status': _selectedStatus,
        'image_url': imageUrl,
        'cover_url': coverUrl,
        'user_id': profile['user_id'] ?? _supabase.auth.currentUser!.id,
      };

      if (profile['id'] != null) {
        await _supabase.from('pcb').update(updateData).eq('id', profile['id']);
      } else {
        await _supabase.from('pcb').insert(updateData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("--- POSTGREST ERROR START ---");
      if (e is PostgrestException) {
        debugPrint("Message: ${e.message}");
        debugPrint("Code: ${e.code}");
        debugPrint("Details: ${e.details}");
        debugPrint("Hint: ${e.hint}");
      } else {
        debugPrint("General Error: $e");
      }
      debugPrint("--- POSTGREST ERROR END ---");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.userData ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 160,
                          width: double.infinity,
                          color: Colors.blueAccent.withOpacity(0.15),
                          child: _coverFile != null
                              ? Image.file(_coverFile!, fit: BoxFit.cover)
                              : (profile['cover_url'] != null && profile['cover_url'].isNotEmpty
                              ? Image.network(profile['cover_url'], fit: BoxFit.cover)
                              : const Icon(Icons.image, size: 50, color: Colors.blueAccent)),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () => _pickAndValidateMedia(isCover: true),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Transform.translate(
                      offset: const Offset(0, -45),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: _imageFile != null
                                        ? FileImage(_imageFile!) as ImageProvider
                                        : (profile['image_url'] != null && profile['image_url'].toString().isNotEmpty
                                        ? NetworkImage(profile['image_url']) as ImageProvider
                                        : null),
                                    child: (_imageFile == null && (profile['image_url'] == null || profile['image_url'].toString().isEmpty))
                                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: () => _pickAndValidateMedia(isCover: false),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildSectionCard(
                title: "Basic Information",
                children: [
                  _buildField("Full Name", _nameController, icon: Icons.badge),
                  _buildSpecialtyDropdown(),
                  _buildGradeDropdown(),
                  _buildStatusDropdown(),
                  _buildField(
                    "Bio",
                    _aboutController,
                    maxLines: 4,
                    maxLength: 130, // Limits characters so it stays concise and shows fully
                    icon: Icons.info_outline,
                    validator: (value) {
                      if (value != null && value.length > 130) {
                        return "Bio cannot exceed 130 characters";
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSectionCard(
                title: "Work & Credentials",
                children: [
                  _buildField(universityLabel, _bmdcController, icon: Icons.business),
                  _buildField(deptLabel, _nidController, icon: Icons.work_outline),
                  _buildField(batchLabel, _hospitalController, icon: Icons.location_on_outlined),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildField(credentialLabel, _pcbLicenseController, icon: Icons.verified_outlined),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            onPressed: _verifyPcbViaCloudFunction,
                            child: const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSectionCard(
                title: "Contact Information",
                children: [
                  _buildField(
                    "Email Address",
                    _emailController,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Email is required";
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return "Enter a valid email address";
                      }
                      return null;
                    },
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildField(
                          "Phone/Mobile",
                          _phoneController,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) return "Phone is required";
                            if (value.length < 10) return "Enter a valid phone number";
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DropdownButtonFormField<String>(
                            value: _phoneVisibility,
                            decoration: InputDecoration(
                              labelText: "Visibility",
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                              ),
                            ),
                            items: _phoneVisibilityOptions.map((String option) {
                              return DropdownMenuItem<String>(
                                value: option,
                                child: Text(option, style: const TextStyle(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _phoneVisibility = newValue!;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: pharmacistTestBanner(adSize: AdSize.banner),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _saveprofile,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const Divider(height: 20, thickness: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(
      String label,
      TextEditingController controller, {
        int maxLines = 1,
        int? maxLength,
        IconData? icon,
        TextInputType? keyboardType, // Changed to allow dynamic override
        String? Function(String?)? validator,
      }) {
    // Automatically use multiline keyboard if maxLines > 1
    final effectiveKeyboardType = keyboardType ?? (maxLines > 1 ? TextInputType.multiline : TextInputType.text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines > 1 ? maxLines : 1, // Keeps the box locked to the 4-line height
        maxLength: maxLength,
        keyboardType: effectiveKeyboardType,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.3, // Ensures lines don't crowd each other and get cut off
        ),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1, // Aligns the label to the top for multi-line boxes
          labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
          prefixIcon: icon != null
              ? Padding(
            // Pushes icon to the top for multi-line inputs so it doesn't center-align awkwardly
            padding: EdgeInsets.only(bottom: maxLines > 1 ? (maxLines * 14.0) : 0),
            child: Icon(icon, color: Colors.blueAccent, size: 22),
          )
              : null,
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
        ),
        validator: validator ?? (value) => (value == null || value.isEmpty) ? "This field is required" : null,
      ),
    );
  }

  Widget _buildSpecialtyDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _selectedSpecialty,
        menuMaxHeight: 300,
        decoration: InputDecoration(
          labelText: "Specialty",
          prefixIcon: const Icon(Icons.medical_services_outlined, color: Colors.blueAccent, size: 22),
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
        ),
        items: _specialtyOptions.map((String specialty) {
          return DropdownMenuItem<String>(
            value: specialty,
            child: Text(specialty, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedSpecialty = newValue;
            _specialtyController.text = newValue!;
          });
        },
        validator: (value) => value == null ? "Please select a specialty" : null,
      ),
    );
  }

  Widget _buildGradeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _selectedGrade,
        menuMaxHeight: 300,
        decoration: InputDecoration(
          labelText: "Grade",
          prefixIcon: const Icon(Icons.military_tech_outlined, color: Colors.blueAccent, size: 22),
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
        ),
        items: _gradeOptions.map((String grade) {
          return DropdownMenuItem<String>(
            value: grade,
            child: Text(grade, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedGrade = newValue;
            _gradeController.text = newValue!;
          });
        },
        validator: (value) => value == null ? "Please select a grade" : null,
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _selectedStatus,
        decoration: InputDecoration(
          labelText: "Availability Status",
          prefixIcon: const Icon(Icons.circle, color: Colors.green, size: 14),
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
        ),
        items: _statusOptions.map((String status) {
          return DropdownMenuItem<String>(
            value: status,
            child: Text(status),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedStatus = newValue!;
          });
        },
      ),
    );
  }
}