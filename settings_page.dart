import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sharebites/overall_files/user_service.dart';
import 'package:sharebites/overall_files/cloudinary_service.dart';
import 'package:sharebites/cnic_verification/cnic_upload_with_verification.dart';
import 'package:sharebites/overall_files/select_location.dart';

class SettingsPage extends StatefulWidget {
  final User user;

  const SettingsPage({super.key, required this.user});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _familySizeController = TextEditingController();
  final TextEditingController _monthlyIncomeController = TextEditingController();
  final TextEditingController _specialNeedsController = TextEditingController();

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPasswordLoading = false;

  late User _user;
  bool _isEditingProfile = false;
  bool _uploadingImage = false;
  bool _uploadingCNIC = false;
  ImageProvider? profileImage;
  File? _cnicFrontImage;
  File? _cnicBackImage;
  LatLng? _selectedLocation;

  bool _notificationsEnabled = true;

  final RegExp passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&]).{8,}$');

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _selectedLocation = _user.location;

    _nameController.text = _user.name;
    _phoneController.text = _user.phone;
    _addressController.text = _user.address ?? '';
    if (_user.userType == 'Acceptor') {
      _familySizeController.text = _user.familySize?.toString() ?? '';
      _monthlyIncomeController.text = _user.monthlyIncome ?? '';
      _specialNeedsController.text = _user.specialNeeds ?? '';
    }

    if (_user.profileImageUrl != null && _user.profileImageUrl!.isNotEmpty) {
      _loadProfileImage();
    }
  }

  void _loadProfileImage() {
    if (_user.profileImageUrl == null || _user.profileImageUrl!.isEmpty) return;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cacheBustedUrl = _user.profileImageUrl!.contains('?')
          ? '${_user.profileImageUrl!}&t=$timestamp'
          : '${_user.profileImageUrl!}?t=$timestamp';

      setState(() {
        profileImage = NetworkImage(
          cacheBustedUrl,
          headers: {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
        );
      });
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        await _authService.signOut();

        if (mounted) {
          Navigator.pop(context);
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _showErrorMessage('Logout Failed', 'Error: ${e.toString()}');
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _familySizeController.dispose();
    _monthlyIncomeController.dispose();
    _specialNeedsController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isPasswordLoading = true);

    try {
      if (_user.authProvider == 'google') {
        _showErrorMessage(
          'Not Available',
          'Password change is not available for Google sign-in accounts.',
        );
        setState(() => _isPasswordLoading = false);
        return;
      }

      final currentPassword = _currentPasswordController.text.trim();
      final newPassword = _newPasswordController.text.trim();

      final auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw Exception('No user logged in');

      final credential = auth.EmailAuthProvider.credential(
        email: _user.email,
        password: currentPassword,
      );

      await firebaseUser.reauthenticateWithCredential(credential);
      await firebaseUser.updatePassword(newPassword);
      await _authService.updateUserPassword(_user.id, newPassword);

      if (mounted) {
        _showSuccessMessage('Password changed successfully!');
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } on auth.FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Current password is incorrect';
          break;
        case 'weak-password':
          errorMessage = 'New password is too weak';
          break;
        case 'requires-recent-login':
          errorMessage = 'Please log out and log in again before changing password';
          break;
        default:
          errorMessage = 'Failed to change password: ${e.message}';
      }
      _showErrorMessage('Password Change Failed', errorMessage);
    } catch (e) {
      _showErrorMessage('Error', 'An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isPasswordLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _uploadingImage = true);

    try {
      final imageUrl = await _cloudinaryService.pickAndUploadProfileImage(_user.id);

      if (imageUrl != null) {
        await _authService.updateProfileImageUrl(_user.id, imageUrl);
        await _authService.refreshUserDataCompletely();

        final updatedUser = _authService.currentUser;
        if (updatedUser != null) {
          setState(() {
            _user = updatedUser;
            profileImage = null;
          });
          _loadProfileImage();
          _showSuccessMessage('Profile picture updated!');
        }
      }
    } catch (e) {
      _showErrorMessage('Upload Failed', 'Error: ${e.toString()}');
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _uploadCNICImages() async {
    if (_cnicFrontImage == null || _cnicBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both CNIC images (front and back)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _uploadingCNIC = true);

    try {
      final urls = await _cloudinaryService.uploadCnicImages(
        _cnicFrontImage!,
        _cnicBackImage!,
        _user.id,
      );

      if (urls['frontUrl'] != null && urls['backUrl'] != null) {
        _user.cnicFrontUrl = urls['frontUrl'];
        _user.cnicBackUrl = urls['backUrl'];

        await _authService.updateProfile(_user);

        setState(() {
          _cnicFrontImage = null;
          _cnicBackImage = null;
        });

        _showSuccessMessage('CNIC images uploaded successfully!');
      }
    } catch (e) {
      _showErrorMessage('Upload Failed', 'Error: ${e.toString()}');
    } finally {
      setState(() => _uploadingCNIC = false);
    }
  }

  void _onCNICImageSelected(File image, String side) {
    setState(() {
      if (side == 'front') {
        _cnicFrontImage = image;
      } else {
        _cnicBackImage = image;
      }
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocation(initialLocation: _selectedLocation),
      ),
    );

    if (result != null && result is LatLng) {
      setState(() => _selectedLocation = result);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    if (_uploadingImage || _uploadingCNIC) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for uploads to complete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your location on the map'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_cnicFrontImage != null || _cnicBackImage != null) {
      if (_cnicFrontImage == null || _cnicBackImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select both CNIC images'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await _uploadCNICImages();
    }

    try {
      _user.name = _nameController.text.trim();
      _user.phone = _phoneController.text.trim();
      _user.address = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null;
      _user.location = _selectedLocation;

      if (_user.userType == 'Acceptor') {
        _user.familySize = int.parse(_familySizeController.text.trim());
        _user.monthlyIncome = _monthlyIncomeController.text.trim();
        _user.specialNeeds = _specialNeedsController.text.trim().isNotEmpty
            ? _specialNeedsController.text.trim()
            : null;
      }

      await _authService.updateProfile(_user);

      setState(() => _isEditingProfile = false);

      _showSuccessMessage('Profile updated successfully!');
      Navigator.pop(context);
    } catch (e) {
      _showErrorMessage('Update Failed', 'Error: ${e.toString()}');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _user.userType == 'Donor' ? Colors.orange : Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: primaryColor),
                            const SizedBox(width: 12),
                            const Text(
                              'Profile Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (!_isEditingProfile)
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => setState(() => _isEditingProfile = true),
                            color: primaryColor,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (!_isEditingProfile)
                      _buildProfileView()
                    else
                      _buildProfileEditForm(primaryColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock, color: primaryColor),
                        const SizedBox(width: 12),
                        const Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_user.authProvider == 'google')
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You signed in with Google. Password change is not available. '
                                    'Please manage your password through Google account settings.',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildPasswordChangeForm(primaryColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: primaryColor),
                        const SizedBox(width: 12),
                        const Text(
                          'Security Tips',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSecurityTip('Use a strong, unique password'),
                    _buildSecurityTip('Don\'t share your password with anyone'),
                    _buildSecurityTip('Keep your profile information up to date'),
                    _buildSecurityTip('Upload your CNIC for verification'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: primaryColor),
                        const SizedBox(width: 12),
                        const Text(
                          'App Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildAppInfoRow('Version', '1.0.0'),
                    _buildAppInfoRow('Build Number', '1'),
                    _buildAppInfoRow('User ID', _user.id.substring(0, 8) + '...'),
                    _buildAppInfoRow('User Type', _user.userType),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: profileImage,
                backgroundColor: Colors.grey[200],
                child: profileImage == null
                    ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildInfoRow('Name', _user.name),
        _buildInfoRow('Email', _user.email),
        _buildInfoRow('Phone', _user.phone),
        _buildInfoRow('User Type', _user.userType),
        _buildInfoRow(
          'Sign-in Method',
          _user.authProvider == 'google' ? 'Google' : 'Email/Password',
        ),

        if (_user.userType == 'Donor' && _user.accountType != null)
          _buildInfoRow('Account Type', _user.accountType!),

        if (_user.userType == 'Acceptor') ...[
          if (_user.familySize != null)
            _buildInfoRow('Family Size', _user.familySize.toString()),
          if (_user.monthlyIncome != null)
            _buildInfoRow('Monthly Income', _user.monthlyIncome!),
        ],

        if (_user.address != null && _user.address!.isNotEmpty)
          _buildInfoRow('Address', _user.address!),

        if (_user.location != null)
          _buildInfoRow(
            'Location',
            'Lat: ${_user.location!.latitude.toStringAsFixed(5)}, '
                'Lng: ${_user.location!.longitude.toStringAsFixed(5)}',
          ),

        _buildInfoRow(
          'CNIC Status',
          _user.cnicVerified == true
              ? 'Verified ✓'
              : (_user.cnicFrontUrl != null && _user.cnicBackUrl != null)
              ? 'Uploaded (Pending verification)'
              : 'Not uploaded',
        ),

        if (_user.specialNeeds != null && _user.specialNeeds!.isNotEmpty)
          _buildInfoRow('Special Needs', _user.specialNeeds!),
      ],
    );
  }

  Widget _buildProfileEditForm(Color primaryColor) {
    return Form(
      key: _profileFormKey,
      child: Column(
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: profileImage,
                  backgroundColor: Colors.grey[200],
                  child: profileImage == null
                      ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: primaryColor,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      onPressed: _uploadingImage ? null : _pickAndUploadImage,
                    ),
                  ),
                ),
                if (_uploadingImage)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your name';
              if (v.trim().length < 3) return 'Name must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
              if (!RegExp(r'^[\d\s\-\+\(\)]+$').hasMatch(v)) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home),
              helperText: 'Your complete address',
            ),
            maxLines: 2,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Address is required';
              if (v.trim().length < 5) return 'Address must be at least 5 characters';
              if (v.length > 200) return 'Address is too long (max 200 characters)';
              return null;
            },
          ),
          const SizedBox(height: 16),

          if (_user.userType == 'Acceptor') ...[
            TextFormField(
              controller: _familySizeController,
              decoration: const InputDecoration(
                labelText: 'Family Size',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.family_restroom),
                helperText: 'Number of family members (Required)',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Family size is required';
                final num = int.tryParse(v.trim());
                if (num == null || num < 1 || num > 50) return 'Please enter a valid number (1-50)';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _monthlyIncomeController,
              decoration: const InputDecoration(
                labelText: 'Monthly Income',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                helperText: 'e.g., "10000-15000" or "Below 5000" (Required)',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Monthly income is required';
                if (v.trim().length > 50) return 'Too long (max 50 characters)';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _specialNeedsController,
              decoration: const InputDecoration(
                labelText: 'Special Needs (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services),
                helperText: 'Describe any specific requirements',
              ),
              maxLines: 3,
              validator: (v) {
                if (v != null && v.trim().isNotEmpty && v.trim().length > 500) {
                  return 'Too long (max 500 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
          ],

          Card(
            elevation: 2,
            margin: const EdgeInsets.only(top: 0, bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your location on the map (Required)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.location_on),
                    label: Text(_selectedLocation == null
                        ? "Select Location on Map"
                        : "Change Location"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  if (_selectedLocation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "📍 Location: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}",
                        style: TextStyle(color: primaryColor, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          CNICUploadWithVerificationWidget(
            frontImageUrl: widget.user.cnicFrontUrl,
            backImageUrl: widget.user.cnicBackUrl,
            onImageSelected: _onCNICImageSelected,
            uploading: _uploadingCNIC,
            verificationNote: widget.user.userType == 'Donor'
                ? 'Donors are auto-verified upon CNIC upload'
                : 'Your CNIC will be verified by an NGO',
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_uploadingImage || _uploadingCNIC) ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: (_uploadingImage || _uploadingCNIC)
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : const Text('Save Profile', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordChangeForm(Color primaryColor) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrentPassword,
            decoration: InputDecoration(
              labelText: 'Current Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureCurrentPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter current password';
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: 'New Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
              helperText: 'At least 8 characters with letters, numbers & special characters',
              helperMaxLines: 2,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter new password';
              if (!passwordRegex.hasMatch(v)) {
                return 'Password must contain:\n• At least 8 characters\n• Letters & numbers\n• Special character (@\$!%*#?&)';
              }
              if (v == _currentPasswordController.text) {
                return 'New password must be different from current password';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_clock),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm new password';
              if (v != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPasswordLoading ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isPasswordLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Change Password', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTip(String tip) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tip, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}