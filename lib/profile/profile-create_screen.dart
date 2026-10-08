import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharmacist_profile/admobs/ads_test_banner.dart';
import 'package:pharmacist_profile/image/cloudinary_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class profileCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const profileCreateScreen({super.key, this.userData});

  @override
  State<profileCreateScreen> createState() => _profileCreateScreenState();
}

class _profileCreateScreenState extends State<profileCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _gradeController = TextEditingController();
  final _aboutController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _emailController = TextEditingController();
  final _bmdcController = TextEditingController();
  final _nidController = TextEditingController();
  final _pcbLicenseController = TextEditingController();
  final TextEditingController _regNumController = TextEditingController();

  String _selectedStatus = "Available";
  final List<String> _statusOptions = ["Available", "Unavailable"];

  // Added state for phone visibility
  String _phoneVisibility = "Public";
  final List<String> _phoneVisibilityOptions = ["Public", "Private"];

  File? _imageFile;
  File? _coverFile; // Added cover image file state
  bool _isLoading = false;
  bool _isOtpSent = false;
  bool _isVerifyingPcb = false;

  final _cloudinary = CloudinaryService();
  final _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker(); // Added ImagePicker instance
  String? _selectedSpecialty;
  String? _selectedGrade;
  final _otpController = TextEditingController();

  final List<String> _specialtyOptions = [
    "Teacher University",
    "Community Pharmacist",
    "Clinical Pharmacist",
    "Hospital Pharmacist",
    "Consultant Pharmacist",
    "Ambulatory Care Pharmacist",
    "Geriatric Pharmacist",
    "Pediatric Pharmacist",
    "Oncology Pharmacist",
    "Psychiatric Pharmacist",
    "Critical Care Pharmacist",
    "Infectious Diseases Pharmacist",
    "Industrial Pharmacist",
    "Compounding Pharmacist",
    "Regulatory Affairs Pharmacist",
    "Pharmacist Researcher",
    "Drug Information Pharmacist",
    "Student Pharmacy"
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
    _aboutController.text = "Write About Yourself.";
  }

  void handleVerify() {
    final name = _nameController.text.trim();
    final grade = _gradeController.text.trim();
    final number = _phoneController.text.trim();

    if (name.isEmpty || grade.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name, grade, and number')),
      );
      return;
    }

    _verifyPcbViaCloudFunction();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await _supabase.auth.signInWithOtp(email: _emailController.text.trim());

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOtpSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification code sent to your email!")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (e.toString().contains('429')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Too many attempts. Please wait 1 minute.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // Updated Image Picker with Policy Dialog, Gallery/Camera choice, and Size Validation
  Future<void> _pickAndValidateMedia({bool isCover = false}) async {
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

    if (!mounted) return;

    // Show Bottom Sheet to choose between Gallery or Camera
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
                final XFile? pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                  maxWidth: isCover ? 1200 : 800,
                );
                if (pickedFile != null) {
                  _validateAndSetFile(File(pickedFile.path), isCover);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text("Take a Picture"),
              onTap: () async {
                Navigator.pop(sheetContext);
                final XFile? pickedFile = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                  maxWidth: isCover ? 1200 : 800,
                );
                if (pickedFile != null) {
                  _validateAndSetFile(File(pickedFile.path), isCover);
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

  Future<void> _verifyAndSave() async {
    if (_otpController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 6-digit verification code")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthResponse res = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        token: _otpController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (res.session != null) {
        String? imageUrl;
        String? coverUrl;

        // 1. Extract old URLs from widget.userData if editing an existing profile
        final String? oldImageUrl = widget.userData?['image_url'];
        final String? oldCoverUrl = widget.userData?['cover_url'];

        // 2. Handle Profile Image Replacement / Deletion
        if (_imageFile != null) {
          if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
            await _cloudinary.deleteMedia(oldImageUrl);
          }
          imageUrl = await _cloudinary.uploadImage(_imageFile!);
        } else {
          imageUrl = oldImageUrl;
        }

        // 3. Handle Cover Image Replacement / Deletion
        if (_coverFile != null) {
          if (oldCoverUrl != null && oldCoverUrl.isNotEmpty) {
            await _cloudinary.deleteMedia(oldCoverUrl);
          }
          coverUrl = await _cloudinary.uploadImage(_coverFile!);
        } else {
          coverUrl = oldCoverUrl;
        }

        // 4. Save/Upsert to Supabase
        await _supabase.from('pcb').upsert({
          'id': res.session!.user.id,
          'name': _nameController.text.trim(),
          'specialization': _selectedSpecialty,
          'grade': _selectedGrade,
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
        });

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile Saved Successfully!")),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Auth Error: ${e.message}");

      String errorMessage = e.message;
      if (errorMessage.contains("expired") || errorMessage.contains("invalid")) {
        errorMessage = "Code expired or invalid. Please click 'Resend' to get a new code.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), duration: const Duration(seconds: 4)),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("FULL DATABASE ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save: $e")),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _supabase.auth.signInWithOtp(email: _emailController.text.trim());

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("A new verification code has been sent!")),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (e.toString().contains('429')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Too many attempts. Please wait 1 minute.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _verifyPcbViaCloudFunction() async {
    final bool isStudent = _selectedSpecialty == "Student Pharmacy";

    if (isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Student profile: Verification bypassed."),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final String credentialLabel = "PCB Licence";

    if (_nameController.text.trim().isEmpty ||
        _gradeController.text.trim().isEmpty ||
        _pcbLicenseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter Name, Grade, and $credentialLabel")),
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
          'is_student': isStudent,
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

  @override
  Widget build(BuildContext context) {
    final bool isStudent = _selectedSpecialty == "Student Pharmacy";
    final String credentialLabel = isStudent ? "Student ID" : "PCB Licence #";
    final String universityLabel = isStudent ? "University Name" : "Company Name";
    final String deptLabel = isStudent ? "Dept Name" : "Job Title";
    final String batchLabel = isStudent ? "Batch" : "Company Location";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_isOtpSent) {
              setState(() => _isOtpSent = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isOtpSent ? "Verify Email" : "Create profile",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: _isOtpSent
            ? _buildInlineOtpView()
            : _buildCreateprofileForm(credentialLabel, universityLabel, deptLabel, batchLabel),
      ),
    );
  }

  // --- REGULAR CREATE PROFILE FORM VIEW ---
  Widget _buildCreateprofileForm(
      String credentialLabel, String universityLabel, String deptLabel, String batchLabel) {
    return Form(
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
                Stack(
                  children: [
                    Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.blueAccent.withOpacity(0.15),
                      child: _coverFile != null
                          ? Image.file(_coverFile!, fit: BoxFit.cover)
                          : const Icon(Icons.image, size: 50, color: Colors.blueAccent),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: InkWell(
                        onTap: () => _pickAndValidateMedia(isCover: true), // Updated handler call
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -35),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                                child: _imageFile == null
                                    ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () => _pickAndValidateMedia(isCover: false), // Updated handler call
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Transform.translate(
                          offset: const Offset(0, -8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem("Views", "0", Icons.remove_red_eye_outlined),
                              _buildStatItem("Followers", "0", Icons.people_outline),
                              _buildStatItem("Following", "0", Icons.person_add_alt_outlined),
                              _buildStatItem("Posts", "0", Icons.article_outlined),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
              onPressed: _isLoading ? null : _sendOtp,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Continue to Verification", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.blueAccent),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildInlineOtpView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 70, color: Colors.blueAccent),
          const SizedBox(height: 16),
          const Text(
            "Verify Your Email Address",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            "We have sent a 6-digit security confirmation code to:\n${_emailController.text.trim()}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: "------",
              counterText: "",
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isLoading ? null : _verifyAndSave,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Verify & Create profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading ? null : _resendOtp,
            child: const Text("Didn't receive code? Resend", style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
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
          labelText: "Specialization",
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
            child: Text(specialty),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedSpecialty = newValue;
          });
        },
        validator: (value) => value == null ? "Please select a specialization" : null,
      ),
    );
  }

  Widget _buildGradeDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _selectedGrade,
        decoration: InputDecoration(
          labelText: "Grade",
          prefixIcon: const Icon(Icons.grade_outlined, color: Colors.blueAccent, size: 22),
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
            child: Text(grade),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedGrade = newValue;
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
          prefixIcon: const Icon(Icons.toggle_on_outlined, color: Colors.blueAccent, size: 22),
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