
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddLeadSheet extends ConsumerStatefulWidget {
  const AddLeadSheet({super.key});

  @override
  ConsumerState<AddLeadSheet> createState() => _AddLeadSheetState();
}

class _AddLeadSheetState extends ConsumerState<AddLeadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _electricityController = TextEditingController();
  final _powerCutController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  final _incentiveController = TextEditingController();
  final _pitchedAmountController = TextEditingController();

  String? _selectedState;
  String? _selectedDistrict;
  bool _isLoading = false;
  String _selectedStatus = 'unassigned';
  bool _accountStatus = false;
  bool _surveyStatus = false;

  // Assignment fields
  Map<String, String?>? _selectedSO;
  List<Map<String, String?>> _availableUsers = [];
  bool _loadingUsers = false;

  final List<String> _statusOptions = [
    'unassigned',
    'assigned',
    'pending',
    'submitted',
    'completed',
    'rejected',
  ];

  final List<String> _availableStates = ['Uttarakhand', 'Uttar Pradesh'];

  final Map<String, List<String>> _stateDistricts = {
    'Uttarakhand': [
      'Almora',
      'Bageshwar',
      'Chamoli',
      'Champawat',
      'Dehradun',
      'Haridwar',
      'Nainital',
      'Pauri Garhwal',
      'Pithoragarh',
      'Rudraprayag',
      'Tehri Garhwal',
      'Udham Singh Nagar',
      'Uttarkashi'
    ],
    'Uttar Pradesh': [
      'Agra',
      'Aligarh',
      'Ambedkar Nagar',
      'Amethi',
      'Amroha',
      'Auraiya',
      'Ayodhya',
      'Azamgarh',
      'Baghpat',
      'Bahraich',
      'Ballia',
      'Balrampur',
      'Banda',
      'Barabanki',
      'Bareilly',
      'Basti',
      'Bhadohi',
      'Bijnor',
      'Budaun',
      'Bulandshahr',
      'Chandauli',
      'Chitrakoot',
      'Deoria',
      'Etah',
      'Etawah',
      'Farrukhabad',
      'Fatehpur',
      'Firozabad',
      'Gautam Buddha Nagar',
      'Ghaziabad',
      'Ghazipur',
      'Gonda',
      'Gorakhpur',
      'Hamirpur',
      'Hapur',
      'Hardoi',
      'Hathras',
      'Jalaun',
      'Jaunpur',
      'Jhansi',
      'Kannauj',
      'Kanpur Dehat',
      'Kanpur Nagar',
      'Kasganj',
      'Kaushambi',
      'Kheri',
      'Kushinagar',
      'Lalitpur',
      'Lucknow',
      'Maharajganj',
      'Mahoba',
      'Mainpuri',
      'Mathura',
      'Mau',
      'Meerut',
      'Mirzapur',
      'Moradabad',
      'Muzaffarnagar',
      'Pilibhit',
      'Pratapgarh',
      'Prayagraj',
      'Raebareli',
      'Rampur',
      'Saharanpur',
      'Sambhal',
      'Sant Kabir Nagar',
      'Shahjahanpur',
      'Shamli',
      'Shrawasti',
      'Siddharthnagar',
      'Sitapur',
      'Sonbhadra',
      'Sultanpur',
      'Unnao',
      'Varanasi'
    ]
  };

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _electricityController.dispose();
    _powerCutController.dispose();
    _additionalInfoController.dispose();
    _incentiveController.dispose();
    _pitchedAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    setState(() => _loadingUsers = true);
    try {
      // Load ALL users from Firestore
      final snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        return <String, String?>{
          'uid': data['uid'] as String?,
          'name': data['name'] as String?,
          'email': data['email'] as String?,
        };
      }).toList();

      setState(() {
        _availableUsers = users;
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() => _loadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _safeInitial(Map<String, String?> user) {
    final name = (user['name'] ?? '').trim();
    if (name.isNotEmpty) return name[0].toUpperCase();

    final email = (user['email'] ?? '').trim();
    if (email.isNotEmpty) return email[0].toUpperCase();

    return 'U';
  }

  String _safeDisplayName(Map<String, String?> user) {
    final name = (user['name'] ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (user['email'] ?? '').trim();
    if (email.isNotEmpty) return email;
    return 'User';
  }

  void _showAssignSODialog() {
    final currentUser = ref.read(currentUserProvider).value;
    final isAdmin =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can assign leads'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (_availableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No users available'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.primaryBlue),
            SizedBox(width: 12),
            Text('Assign Sales Officer'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a Sales Officer:',
                style: TextStyle(
                  color: AppTheme.mediumGrey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = _availableUsers[index];
                    final uid = (user['uid'] ?? '').trim();
                    final isSelected = _selectedSO?['uid'] == uid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppTheme.primaryBlue.withOpacity(0.2)
                            : AppTheme.mediumGrey.withOpacity(0.1),
                        child: Text(
                          _safeInitial(user),
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.mediumGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(_safeDisplayName(user)),
                      subtitle: Text((user['email'] ?? '').trim()),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryBlue,
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedSO = user;
                        });
                        Navigator.pop(dialogCtx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_selectedSO != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedSO = null;
                });
                Navigator.pop(dialogCtx);
              },
              child: const Text(
                'Clear Selection',
                style: TextStyle(color: AppTheme.errorRed),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      final leadService = ref.read(leadServiceProvider);

      final leadId = DateTime.now().millisecondsSinceEpoch.toString();

      final newLead = LeadPool(
        uid: leadId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        number: _numberController.text.trim(),
        address: _addressController.text.trim(),
        location: _selectedDistrict ?? '',
        state: _selectedState ?? '',
        electricityConsumption: _electricityController.text.trim(),
        powercut: _powerCutController.text.trim(),
        additionalInfo: _additionalInfoController.text.trim(),
        status: _selectedSO != null ? 'assigned' : _selectedStatus,
        accountStatus: _accountStatus,
        surveyStatus: _surveyStatus,
        createdBy: currentUser?.email ?? '',
        createdTime: DateTime.now(),
        date: DateTime.now(),
        incentive: int.tryParse(_incentiveController.text.trim()) ?? 0,
        pitchedAmount: int.tryParse(_pitchedAmountController.text.trim()) ?? 0,
        offer: null,
        assignedTo: _selectedSO?['uid'],
        assignedToName: _selectedSO?['name'],
        assignedAt: _selectedSO != null ? DateTime.now() : null,
      );

      // Add lead to leadpool
      await leadService.addLead(newLead);

      // If assigned, start SLA
      if (_selectedSO != null) {
        await leadService.startRegistrationSla(leadId);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedSO != null
                        ? 'Lead created and assigned to ${_selectedSO!['name']}!'
                        : 'Lead added successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(currentUserProvider).value;
    final isAdmin =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mediumGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Lead',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Fill in the details below',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.mediumGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Required Fields Section
                      _buildSectionHeader('Lead Details', true),
                      const SizedBox(height: 16),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name *',
                          hintText: 'Enter customer name',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Number Field
                      TextFormField(
                        controller: _numberController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Phone Number *',
                          hintText: 'Enter 10-digit number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter phone number';
                          }
                          if (value.length != 10) {
                            return 'Phone number must be 10 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // State Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedState,
                        decoration: InputDecoration(
                          labelText: 'State *',
                          prefixIcon: const Icon(Icons.map_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _availableStates.map((state) {
                          return DropdownMenuItem(
                            value: state,
                            child: Text(state),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedState = value;
                            _selectedDistrict = null;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select state';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // District Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedDistrict,
                        decoration: InputDecoration(
                          labelText: 'District/Location *',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _selectedState != null
                            ? _stateDistricts[_selectedState]!.map((district) {
                                return DropdownMenuItem(
                                  value: district,
                                  child: Text(district),
                                );
                              }).toList()
                            : [],
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrict = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select district';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Assignment Section (Only for Admins)
                      if (isAdmin) ...[
                        _buildSectionHeader('Assignment (Optional)'),
                        const SizedBox(height: 12),
                        if (_loadingUsers)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _showAssignSODialog,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _selectedSO != null
                                      ? AppTheme.primaryBlue
                                      : AppTheme.mediumGrey.withOpacity(0.3),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: _selectedSO != null
                                    ? AppTheme.primaryBlue.withOpacity(0.05)
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (_selectedSO != null
                                              ? AppTheme.primaryBlue
                                              : AppTheme.mediumGrey)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _selectedSO != null
                                          ? Icons.person
                                          : Icons.person_add_outlined,
                                      color: _selectedSO != null
                                          ? AppTheme.primaryBlue
                                          : AppTheme.mediumGrey,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedSO != null
                                              ? 'Assigned to'
                                              : 'Assign Sales Officer',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.mediumGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedSO != null
                                              ? _safeDisplayName(_selectedSO!)
                                              : 'Tap to select (optional)',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: _selectedSO != null
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _selectedSO != null
                                                ? AppTheme.primaryBlue
                                                : AppTheme.mediumGrey,
                                          ),
                                        ),
                                        if (_selectedSO != null)
                                          Text(
                                            _selectedSO!['email'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.mediumGrey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (_selectedSO != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.successGreen.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppTheme.successGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Registration SLA (30 days) will start automatically when assigned',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.darkGrey.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],

                      // Contact Information Section
                      _buildSectionHeader('Contact Information'),
                      const SizedBox(height: 12),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter email address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Address Field
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          hintText: 'Enter full address',
                          prefixIcon: const Icon(Icons.home_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Energy Details Section
                      _buildSectionHeader('Energy Details'),
                      const SizedBox(height: 12),

                      // Electricity Consumption Field
                      TextFormField(
                        controller: _electricityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Electricity Consumption (kWh)',
                          hintText: 'Monthly consumption',
                          prefixIcon: const Icon(Icons.bolt_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Power Cut Hours Field
                      TextFormField(
                        controller: _powerCutController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Power Cut (hours/day)',
                          hintText: 'Average power cut duration',
                          prefixIcon: const Icon(Icons.power_off_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Business Details Section
                      _buildSectionHeader('Business Details'),
                      const SizedBox(height: 12),

                      // Pitched Amount Field
                      TextFormField(
                        controller: _pitchedAmountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Pitched Amount (₹)',
                          hintText: 'Enter pitched amount',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Status & Progress Section
                      _buildSectionHeader('Status & Progress'),
                      const SizedBox(height: 12),

                      // Status Dropdown (Only show if not assigning)
                      if (_selectedSO == null)
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            labelText: 'Lead Status',
                            prefixIcon: const Icon(Icons.flag_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(_getStatusLabel(status)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.successGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: AppTheme.successGreen,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Status will be set to: ',
                                style: TextStyle(fontSize: 14),
                              ),
                              Text(
                                'ASSIGNED',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Status Switches Card

                      const SizedBox(height: 24),

                      // Additional Information Section
                      _buildSectionHeader('Additional Information'),
                      const SizedBox(height: 12),

                      // Additional Info Field
                      TextFormField(
                        controller: _additionalInfoController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Any other details or special notes',
                          prefixIcon: const Icon(Icons.notes_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Info Note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningAmber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warningAmber.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppTheme.warningAmber,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedSO != null
                                    ? 'Lead will be created and assigned to ${_safeDisplayName(_selectedSO!)}. Registration SLA will start immediately.'
                                    : 'Lead will be created with status: ${_getStatusLabel(_selectedStatus)}. Admins can assign it to a Sales Officer later.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.darkGrey.withOpacity(0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      Container(
                        height: 56,
                        decoration: AppTheme.orangeGradientDecoration,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitLead,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_circle_outline,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedSO != null
                                          ? 'Create & Assign Lead'
                                          : 'Add Lead',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, [bool isRequired = false]) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: AppTheme.errorRed,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'unassigned':
        return 'Unassigned';
      case 'assigned':
        return 'Assigned';
      case 'pending':
        return 'Pending';
      case 'submitted':
        return 'Submitted';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}
