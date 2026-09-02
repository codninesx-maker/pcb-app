import 'dart:io';
import 'package:doctor_profile/admobs/ads_test_banner.dart';
import 'package:doctor_profile/image/cloudinary_service.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const EditProfileScreen({super.key, required this.doctor});

  @override
  State<EditProfileScreen> createState() => _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState extends State<EditProfileScreen> {
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

  String _selectedStatus = "Available";
  final List<String> _statusOptions = ["Available", "Unavailable"];

  bool get _isStudent => _selectedSpecialty == "Student Pharmacy" || _selectedGrade == "Student";
  String get universityLabel => _isStudent ? "University / Institute" : "Company Name";
  String get deptLabel => _isStudent ? "Department" : "Job Title";
  String get batchLabel => _isStudent ? "Batch / Session" : "Company Location";
  String get credentialLabel => _isStudent ? "Student ID / Roll" : "BPC Licence #";

  // Phone visibility state options
  String _phoneVisibility = "Public";
  final List<String> _phoneVisibilityOptions = ["Public", "Private"];

  String? _selectedSpecialty;
  String? _selectedGrade;

  File? _imageFile;
  File? _coverFile; // Added cover image file state
  bool _isLoading = false;
  bool _isVerifyingBpc = false; // Added BPC verification state

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
    _nameController.text = widget.doctor['name'] ?? "";
    _specialtyController.text = widget.doctor['specialization'] ?? "";
    _gradeController.text = widget.doctor['grade'] ?? "";
    _aboutController.text = widget.doctor['about_profile'] ?? "";
    _bmdcController.text = widget.doctor['company_name'] ?? "";
    _nidController.text = widget.doctor['company_name'] ?? "";
    _hospitalController.text = widget.doctor['job_location'] ?? "";
    _pcbLicenseController.text = widget.doctor['pcb_licence'] ?? "";
    _emailController.text = widget.doctor['email'] ?? "";
    _phoneController.text = widget.doctor['phone'] ?? "";
    _selectedStatus = widget.doctor['status'] ?? "Available";

    // Load phone visibility from existing data or default to Public
    _phoneVisibility = widget.doctor['phone_visibility'] ?? "Public";
    if (!_phoneVisibilityOptions.contains(_phoneVisibility)) {
      _phoneVisibility = "Public";
    }

    _selectedSpecialty = _specialtyOptions.contains(widget.doctor['specialization'])
        ? widget.doctor['specialization']
        : null;

    _selectedGrade = _gradeOptions.contains(widget.doctor['grade'])
        ? widget.doctor['grade']
        : null;
  }

  Future<void> _pickImage({bool isCover = false}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: isCover ? 1200 : 800,
      );
      if (pickedFile != null) {
        setState(() {
          if (isCover) {
            _coverFile = File(pickedFile.path);
          } else {
            _imageFile = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      debugPrint("DEBUG: Error picking image: $e");
    }
  }

  Future<void> _verifyBpcViaCloudFunction() async {
    // Check if the user is selecting Student Pharmacy / Student Grade
    bool isStudent = _selectedSpecialty == "Student Pharmacy" || _selectedGrade == "Student";

    if (isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Student profile: Verification bypassed"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      return; // Skip cloud function call entirely for students
    }

    if (_nameController.text.trim().isEmpty ||
        _gradeController.text.trim().isEmpty ||
        _pcbLicenseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter Name, Grade, and BPC Licence")),
      );
      return;
    }

    if (_isVerifyingBpc) return;
    setState(() => _isVerifyingBpc = true);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verifying credentials against registry...")),
      );

      final response = await _supabase.functions.invoke(
        'verify-bpc',
        body: {
          'name': _nameController.text.trim(),
          'pcb_licence': _pcbLicenseController.text.trim(),
          'is_student': false,
        },
      );

      setState(() => _isVerifyingBpc = false);

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
      setState(() => _isVerifyingBpc = false);
      debugPrint("Verification Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? imageUrl = widget.doctor['image_url'];
      String? coverUrl = widget.doctor['cover_url'];

      if (_imageFile != null) {
        imageUrl = await _cloudinary.uploadImage(_imageFile!);
      }
      if (_coverFile != null) {
        coverUrl = await _cloudinary.uploadImage(_coverFile!);
      }

      await _supabase.from('pcb').update({
        'name': _nameController.text.trim(),
        'specialization': _selectedSpecialty, // <-- Use state variable directly
        'grade': _selectedGrade,               // <-- Use state variable directly
        'about_profile': _aboutController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone_visibility': _phoneVisibility,
        'job_location': _hospitalController.text.trim(),
        'pcb_licence': _pcbLicenseController.text.trim(),
        'email': _emailController.text.trim(),
        'company_name': _nidController.text.trim(),
        'status': _selectedStatus,
        'image_url': imageUrl,
        'cover_url': coverUrl,
        'user_id': _supabase.auth.currentUser!.id,
      }).eq('id', widget.doctor['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully!")));
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
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // --- FACEBOOK-STYLE PROFILE & COVER HEADER ---
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
                    // 1. Cover Photo Banner with Camera Button
                    Stack(
                      children: [
                        Container(
                          height: 160,
                          width: double.infinity,
                          color: Colors.blueAccent.withOpacity(0.15),
                          child: _coverFile != null
                              ? Image.file(_coverFile!, fit: BoxFit.cover)
                              : (widget.doctor['cover_url'] != null && widget.doctor['cover_url'].isNotEmpty
                              ? Image.network(widget.doctor['cover_url'], fit: BoxFit.cover)
                              : const Icon(Icons.image, size: 50, color: Colors.blueAccent)),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: () => _pickImage(isCover: true),
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
                    // 2. Profile Avatar overlapping the Cover Section
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
                                        ? FileImage(_imageFile!)
                                        : (widget.doctor['image_url'] != null && widget.doctor['image_url'].isNotEmpty
                                        ? NetworkImage(widget.doctor['image_url'])
                                        : null) as ImageProvider<Object>?,
                                    child: _imageFile == null && (widget.doctor['image_url'] == null || widget.doctor['image_url'].isEmpty)
                                        ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: InkWell(
                                    onTap: () => _pickImage(isCover: false),
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

              // --- SECTION 1: BASIC INFORMATION ---
              _buildSectionCard(
                title: "Basic Information",
                children: [
                  _buildField("Full Name", _nameController, icon: Icons.badge),
                  _buildSpecialtyDropdown(),
                  _buildGradeDropdown(),
                  _buildStatusDropdown(),
                  _buildField("Bio", _aboutController, maxLines: 4, icon: Icons.info_outline),
                ],
              ),
              const SizedBox(height: 12),

              // --- SECTION 2: WORK & CREDENTIALS ---
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
                            onPressed: _verifyBpcViaCloudFunction,
                            child: const Text("Verify", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // --- SECTION 3: CONTACT INFORMATION ---
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
                child: DoctorTestBanner(adSize: AdSize.largeBanner),
              ),
              const SizedBox(height: 10),

              // --- SUBMIT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _saveProfile,
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
        IconData? icon,
        TextInputType keyboardType = TextInputType.text,
        String? Function(String?)? validator,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueAccent, size: 22) : null,
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