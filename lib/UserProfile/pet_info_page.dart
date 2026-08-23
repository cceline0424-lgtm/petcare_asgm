import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petcare_asgm/Auth/auth_service.dart';

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
}

class PetInfoPage extends StatefulWidget {
  const PetInfoPage({super.key});

  @override
  State<PetInfoPage> createState() => _PetInfoPageState();
}

class _PetInfoPageState extends State<PetInfoPage> {
  final List<PetRecord> _myPets = [];
  final ImagePicker _picker = ImagePicker();

  String? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    _currentUser = await AuthService.getLoggedInUsername();

    if (_currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();

    final List<String>? manualPetsJson = prefs.getStringList('my_pets_$_currentUser');
    final List<String>? adoptedPetsJson = prefs.getStringList('user_adopted_pets_$_currentUser');

    setState(() {
      _myPets.clear();

      if (manualPetsJson != null) {
        for (String jsonStr in manualPetsJson) {
          try {
            final data = jsonDecode(jsonStr);
            _myPets.add(PetRecord.fromJson(data));
          } catch (e) {}
        }
      }

      if (adoptedPetsJson != null) {
        for (String jsonStr in adoptedPetsJson) {
          try {
            final data = jsonDecode(jsonStr);
            data['isAdopted'] = true;
            data['age'] = data['age']?.toString().replaceAll(' Years', '').replaceAll(' Year', '').replaceAll(' Months', '');
            _myPets.add(PetRecord.fromJson(data));
          } catch (e) {}
        }
      }
    });
  }

  Future<void> _savePets() async {
    if (_currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final List<String> petsJson = _myPets
        .where((p) => !p.isAdopted)
        .map((p) => jsonEncode(p.toJson()))
        .toList();
    
    await prefs.setStringList('my_pets_$_currentUser', petsJson);
  }

  Future<void> _showPetDialog([PetRecord? existingPet]) async {
    final nameCtrl = TextEditingController(text: existingPet?.name ?? '');
    final speciesCtrl = TextEditingController(text: existingPet?.species ?? '');
    final breedCtrl = TextEditingController(text: existingPet?.breed ?? '');
    final ageCtrl = TextEditingController(text: existingPet?.age ?? '');
    String selectedGender = (existingPet != null && existingPet.gender.isNotEmpty) ? existingPet.gender : 'Male';
    File? tempImage = existingPet?.imagePath.isNotEmpty == true ? File(existingPet!.imagePath) : null;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;

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
                          final appDataDir = await getApplicationDocumentsDirectory();
                          final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
                          final savedImage = await File(pickedFile.path).copy('${appDataDir.path}/$fileName');

                          setDialogState(() {
                            tempImage = savedImage;
                          });
                        }
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.brown[200],
                            backgroundImage: tempImage != null ? FileImage(tempImage!) : null,
                            child: tempImage == null
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;

                    setState(() {
                      if (existingPet == null) {
                        _myPets.add(PetRecord(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameCtrl.text.trim(),
                          species: speciesCtrl.text.trim(),
                          breed: breedCtrl.text.trim(),
                          age: ageCtrl.text.trim(),
                          gender: selectedGender,
                          imagePath: tempImage?.path ?? '',
                        ));
                      } else {
                        existingPet.name = nameCtrl.text.trim();
                        existingPet.species = speciesCtrl.text.trim();
                        existingPet.breed = breedCtrl.text.trim();
                        existingPet.age = ageCtrl.text.trim();
                        existingPet.gender = selectedGender;
                        existingPet.imagePath = tempImage?.path ?? '';
                      }
                    });

                    _savePets();
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePet(PetRecord pet) async {
    if (_currentUser == null) return;

    setState(() {
      _myPets.removeWhere((p) => p.id == pet.id && p.name == pet.name);
    });

    if (pet.isAdopted) {
      final prefs = await SharedPreferences.getInstance();
      final adoptedPetsJson = prefs.getStringList('user_adopted_pets_$_currentUser') ?? [];

      adoptedPetsJson.removeWhere((jsonStr) {
        final data = jsonDecode(jsonStr);
        return data['name'] == pet.name;
      });
      await prefs.setStringList('user_adopted_pets_$_currentUser', adoptedPetsJson);
    } else {
      _savePets();
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
      body: _myPets.isEmpty
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

          ImageProvider? petImage;
          if (pet.imagePath.isNotEmpty) {
            if (pet.isAdopted) {
              petImage = NetworkImage(pet.imagePath);
            } else {
              petImage = FileImage(File(pet.imagePath));
            }
          }

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