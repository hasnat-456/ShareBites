import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:sharebites/models/ngo_model.dart';
import 'package:sharebites/verifier/ngo_service.dart';
import 'package:sharebites/overall_files/select_location.dart';

class NGOSettings extends StatefulWidget {
  final NGO ngo;

  const NGOSettings({super.key, required this.ngo});

  @override
  State<NGOSettings> createState() => _NGOSettingsState();
}

class _NGOSettingsState extends State<NGOSettings> {
  final _formKey = GlobalKey<FormState>();
  final NGOService _ngoService = NGOService();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isEditingProfile = false;
  bool _isChangingPassword = false;
  bool _isSavingProfile = false;
  bool _isChangingPasswordAction = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _notificationsEnabled = true;
  bool _loadingNotifications = false;
  bool _isClearingData = false;

  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadNGOData();
    _loadNotificationSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadNGOData() {
    _nameController.text = widget.ngo.name;
    _emailController.text = widget.ngo.email;
    _phoneController.text = widget.ngo.phone;
    _addressController.text = widget.ngo.address;
    _selectedLocation = widget.ngo.location;
  }

  Future<void> _loadNotificationSettings() async {
    setState(() => _loadingNotifications = true);
    try {
      final snapshot = await _databaseRef
          .child('notification_settings')
          .child(widget.ngo.id)
          .once();

      if (snapshot.snapshot.exists) {
        final data = Map<String, dynamic>.from(
            snapshot.snapshot.value as Map<dynamic, dynamic>);
        setState(() {
          _notificationsEnabled = data['enabled'] ?? true;
        });
      } else {
        await _databaseRef
            .child('notification_settings')
            .child(widget.ngo.id)
            .set({
          'enabled': true,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
        setState(() => _notificationsEnabled = true);
      }
    } catch (e) {
      print('Error loading notification settings: $e');
      setState(() => _notificationsEnabled = true);
    } finally {
      setState(() => _loadingNotifications = false);
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      await _databaseRef
          .child('notification_settings')
          .child(widget.ngo.id)
          .update({
        'enabled': _notificationsEnabled,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_notificationsEnabled
              ? 'Notifications enabled'
              : 'Notifications disabled'),
          backgroundColor:
          _notificationsEnabled ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving notification settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectLocation(initialLocation: _selectedLocation),
      ),
    );
    if (picked != null) {
      setState(() => _selectedLocation = picked);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      _showErrorMessage(
          'Location Required', 'Please select NGO location on the map');
      return;
    }

    setState(() => _isSavingProfile = true);

    try {
      final updatedNGO = NGO(
        id: widget.ngo.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        location: _selectedLocation!,
        defaultPassword: widget.ngo.defaultPassword,
        currentPassword: widget.ngo.currentPassword,
        isPasswordChanged: widget.ngo.isPasswordChanged,
        createdAt: widget.ngo.createdAt,
        verifiedCount: widget.ngo.verifiedCount,
        pendingCount: widget.ngo.pendingCount,
      );

      await _databaseRef.child('ngos').child(widget.ngo.id).update({
        'name': updatedNGO.name,
        'email': updatedNGO.email,
        'phone': updatedNGO.phone,
        'address': updatedNGO.address,
        'latitude': updatedNGO.location.latitude,
        'longitude': updatedNGO.location.longitude,
      });

      setState(() {
        _isEditingProfile = false;
        widget.ngo.name = updatedNGO.name;
        widget.ngo.email = updatedNGO.email;
        widget.ngo.phone = updatedNGO.phone;
        widget.ngo.address = updatedNGO.address;
        widget.ngo.location = updatedNGO.location;
      });

      _showSuccessMessage('Profile updated successfully!');
    } catch (e) {
      _showErrorMessage('Update Failed', 'Error updating profile: $e');
    } finally {
      setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isChangingPasswordAction = true);

    try {
      await _ngoService.changePassword(
        widget.ngo.id,
        _oldPasswordController.text.trim(),
        _newPasswordController.text.trim(),
      );

      setState(() {
        _isChangingPassword = false;
        _isChangingPasswordAction = false;
        _oldPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      _showSuccessMessage('Password changed successfully!');
    } catch (e) {
      setState(() => _isChangingPasswordAction = false);
      _showErrorMessage('Password Change Failed', e.toString());
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── DANGER ZONE ────────────────────────────────────────────────────

  Future<void> _confirmAndClearAllData() async {
    // First confirmation dialog
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Clear All Data', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL app data including:\n\n'
              '• All users and their profiles\n'
              '• All verification requests\n'
              '• All donations and requests\n'
              '• All received donations\n'
              '• All notification history (Supabase)\n'
              '• All notification device tokens\n\n'
              'NGO accounts will be kept but their statistics will be reset to zero.\n\n'
              'This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirmation — must type DELETE
    final confirmController = TextEditingController();
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Are you absolutely sure?',
            style: TextStyle(color: Colors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type DELETE below to confirm you want to wipe all data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type DELETE',
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: confirmController.text.trim() == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('DELETE ALL DATA'),
            ),
          ],
        ),
      ),
    );

    if (secondConfirm != true || !mounted) return;

    setState(() => _isClearingData = true);

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 20),
            Text('Clearing all data...\nPlease wait.'),
          ],
        ),
      ),
    );

    try {
      final result = await _ngoService.clearAllAppData();
      final errors = result['errors'] as List<String>;

      if (!mounted) return;
      Navigator.pop(context); // close progress dialog
      setState(() => _isClearingData = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                errors.isEmpty
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                color: errors.isEmpty ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 10),
              Text(errors.isEmpty ? 'Data Cleared' : 'Partially Cleared'),
            ],
          ),
          content: Text(
            errors.isEmpty
                ? 'All app data has been successfully deleted, including all Supabase notification history and device tokens.'
                : 'Most data was cleared but some errors occurred:\n\n${errors.join("\n")}',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close progress
      setState(() => _isClearingData = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDangerZoneCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.red, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dangerous, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.red),
            const Text(
              'Clear All App Data',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Permanently deletes all users, verification requests, donations, '
                  'and notification history from both Firebase and Supabase. '
                  'NGO accounts are preserved but statistics are reset.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isClearingData ? null : _confirmAndClearAllData,
                icon: _isClearingData
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.delete_forever),
                label: Text(_isClearingData ? 'Clearing...' : 'Clear All Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Profile Card ──────────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Profile Information',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (!_isEditingProfile)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  setState(() => _isEditingProfile = true),
                              tooltip: 'Edit Profile',
                            ),
                        ],
                      ),
                      const Divider(height: 20),

                      TextFormField(
                        controller: _nameController,
                        enabled: _isEditingProfile,
                        decoration: const InputDecoration(
                          labelText: 'Organization Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter organization name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        enabled: _isEditingProfile,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter email';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneController,
                        enabled: _isEditingProfile,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter phone number'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _addressController,
                        enabled: _isEditingProfile,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter address'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      if (_isEditingProfile) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickLocation,
                            icon: const Icon(Icons.map),
                            label: Text(_selectedLocation != null
                                ? 'Update Location on Map'
                                : 'Select Location on Map'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSavingProfile
                                    ? null
                                    : () => setState(() {
                                  _isEditingProfile = false;
                                  _loadNGOData();
                                }),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSavingProfile
                                    ? null
                                    : _saveProfileChanges,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue),
                                child: _isSavingProfile
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2),
                                )
                                    : const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Notifications Card ────────────────────────────────────
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 20),
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: Text(
                        _notificationsEnabled
                            ? 'You will receive notifications for new verification requests'
                            : 'Notifications are turned off',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: _notificationsEnabled,
                      onChanged: _loadingNotifications
                          ? null
                          : (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveNotificationSettings();
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Security Card ─────────────────────────────────────────
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
                        const Text(
                          'Security',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (!_isChangingPassword)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _isChangingPassword = true),
                            icon: const Icon(Icons.lock),
                            label: const Text('Change Password'),
                          ),
                      ],
                    ),
                    const Divider(height: 20),

                    if (!_isChangingPassword)
                      Column(
                        children: [
                          const Icon(Icons.security,
                              size: 60, color: Colors.green),
                          const SizedBox(height: 10),
                          const Text('Your account is secure',
                              style:
                              TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text(
                            widget.ngo.isPasswordChanged
                                ? 'Password has been changed from default'
                                : 'Using default password',
                            style: TextStyle(
                              color: widget.ngo.isPasswordChanged
                                  ? Colors.green
                                  : Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          if (!widget.ngo.isPasswordChanged)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange.shade700),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'You are using the default password. Please change it for security.',
                                      style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          TextFormField(
                            controller: _oldPasswordController,
                            obscureText: _obscureOldPassword,
                            decoration: InputDecoration(
                              labelText: 'Current Password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureOldPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(() =>
                                _obscureOldPassword =
                                !_obscureOldPassword),
                              ),
                            ),
                            validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Please enter current password'
                                : null,
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock),
                              helperText: 'At least 8 characters',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureNewPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(() =>
                                _obscureNewPassword =
                                !_obscureNewPassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter new password';
                              }
                              if (v.length < 8) {
                                return 'Password must be at least 8 characters';
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
                                icon: Icon(_obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please confirm new password';
                              }
                              if (v != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isChangingPasswordAction
                                      ? null
                                      : () => setState(() {
                                    _isChangingPassword = false;
                                    _oldPasswordController.clear();
                                    _newPasswordController.clear();
                                    _confirmPasswordController
                                        .clear();
                                  }),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isChangingPasswordAction
                                      ? null
                                      : _changePassword,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue),
                                  child: _isChangingPasswordAction
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2),
                                  )
                                      : const Text('Change'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Danger Zone ───────────────────────────────────────────
            _buildDangerZoneCard(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}