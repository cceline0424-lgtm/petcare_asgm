import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PetRecord {
  String id;
  String name;
  String species;
  String breed;
  String age;
  String gender;
  String imagePath;
  bool isAdopted;

  PetRecord({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.gender,
    this.imagePath = '',
    this.isAdopted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'gender': gender,
      'imagePath': imagePath,
      'isAdopted': isAdopted,
    };
  }

  factory PetRecord.fromJson(Map<String, dynamic> json) {
    return PetRecord(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      species: json['species'] ?? json['type'] ?? '',
      breed: json['breed'] ?? '',
      age: json['age']?.toString() ?? '',
      gender: json['gender'] ?? 'Unknown',
      imagePath: json['imagePath'] ?? json['photoUrl'] ?? '',
      isAdopted: json['isAdopted'] ?? false,
    );
  }

  ImageProvider? get photoProvider {
    if (imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    return FileImage(File(imagePath));
  }
}

class PetInfoPage extends StatefulWidget {
  const PetInfoPage({super.key});

  @override
  State<PetInfoPage> createState() => _PetInfoPageState();
}

class _PetInfoPageState extends State<PetInfoPage> {
  final List<PetRecord> _myPets = [];
  final ImagePicker _picker = ImagePicker();

  String? _uid;
  bool _isLoading = true;

  CollectionReference<Map<String, dynamic>> get _petsCollection =>
      FirebaseFirestore.instance.collection('pets');

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() => _isLoading = true);

    _uid = FirebaseAuth.instance.currentUser?.uid;

    if (_uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final List<PetRecord> loaded = [];
    try {
      final snap = await _petsCollection.where('uid', isEqualTo: _uid).get();
      for (final doc in snap.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        loaded.add(PetRecord.fromJson(data));
      }
    } catch (_) {

    }

    if (!mounted) return;
    setState(() {
      _myPets
        ..clear()
        ..addAll(loaded);
      _isLoading = false;
    });
  }

  Future<String> _savePhotoLocally(File file, String petId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final petPhotosDir = Directory('${docsDir.path}/pet_photos/$_uid');
    if (!await petPhotosDir.exists()) {
      await petPhotosDir.create(recursive: true);
    }
    final ext = file.path.contains('.') ? file.path.substring(file.path.lastIndexOf('.')) : '.jpg';
    final savedPath = '${petPhotosDir.path}/$petId$ext';
    await file.copy(savedPath);
    return savedPath;
  }

  Future<void> _deletePhotoIfAny(String imagePath) async {
    if (imagePath.isEmpty || imagePath.startsWith('http')) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> _showPetDialog([PetRecord? existingPet]) async {
    final nameCtrl = TextEditingController(text: existingPet?.name ?? '');
    final speciesCtrl = TextEditingController(text: existingPet?.species ?? '');
    final breedCtrl = TextEditingController(text: existingPet?.breed ?? '');
    final ageCtrl = TextEditingController(text: existingPet?.age ?? '');
    String selectedGender = (existingPet != null && existingPet.gender.isNotEmpty) ? existingPet.gender : 'Male';

    File? tempImage;
    String? existingImageUrl = existingPet?.imagePath.isNotEmpty == true ? existingPet!.imagePath : null;
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;

            ImageProvider? previewImage;
            if (tempImage != null) {
              previewImage = FileImage(tempImage!);
            } else if (existingImageUrl != null) {
              previewImage = existingImageUrl!.startsWith('http')
                  ? NetworkImage(existingImageUrl!)
                  : FileImage(File(existingImageUrl!));
            }

            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[850] : Colors.white,
              title: Text(
                existingPet == null ? 'Add New Pet' : 'Edit Pet',
                style: TextStyle(color: isDark ? Colors.white : Colors.brown, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          setDialogState(() {
                            tempImage = File(pickedFile.path);
                          });
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.brown[200],
                            backgroundImage: previewImage,
                            child: previewImage == null
                                ? const Icon(Icons.pets, size: 40, color: Colors.white)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.brown,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Pet Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: speciesCtrl,
                      decoration: const InputDecoration(labelText: 'Species (e.g., Dog, Cat)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: breedCtrl,
                      decoration: const InputDecoration(labelText: 'Breed', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                      items: ['Male', 'Female', 'Unknown'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          selectedGender = newValue!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageCtrl,
                      decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                  onPressed: isSaving
                      ? null
                      : () async {
                    if (nameCtrl.text.trim().isEmpty || _uid == null) return;

                    setDialogState(() => isSaving = true);

                    final petId = existingPet?.id ?? _petsCollection.doc().id;
                    String imageUrl = existingImageUrl ?? '';

                    try {
                      if (tempImage != null) {
                        if (existingImageUrl != null) {
                          await _deletePhotoIfAny(existingImageUrl!);
                        }
                        imageUrl = await _savePhotoLocally(tempImage!, petId);
                      }

                      final petData = PetRecord(
                        id: petId,
                        name: nameCtrl.text.trim(),
                        species: speciesCtrl.text.trim(),
                        breed: breedCtrl.text.trim(),
                        age: ageCtrl.text.trim(),
                        gender: selectedGender,
                        imagePath: imageUrl,
                      );

                      await _petsCollection.doc(petId).set({
                        ...petData.toJson(),
                        'uid': _uid,
                      });

                      if (context.mounted) Navigator.pop(context);
                      await _loadPets();
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save pet: $e')),
                        );
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePet(PetRecord pet) async {
    setState(() {
      _myPets.removeWhere((p) => p.id == pet.id && p.name == pet.name);
    });

    try {
      await _petsCollection.doc(pet.id).delete();
      if (pet.imagePath.isNotEmpty) {
        await _deletePhotoIfAny(pet.imagePath);
      }
    } catch (_) {
      _loadPets();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.brown[900]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : _myPets.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "You haven't added any pets yet.",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myPets.length,
        itemBuilder: (context, index) {
          final pet = _myPets[index];
          final ImageProvider? petImage = pet.photoProvider;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.brown[100],
                    backgroundImage: petImage,
                    child: petImage == null ? Icon(Icons.pets, color: Colors.brown[400], size: 30) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pet.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 4),
                        Text('${pet.species} • ${pet.breed} • ${pet.gender}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('${pet.age} yrs', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (!pet.isAdopted)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showPetDialog(pet),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePet(pet),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.brown,
        onPressed: () => _showPetDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Pet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}