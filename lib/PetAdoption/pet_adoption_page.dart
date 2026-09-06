import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_details_page.dart';

class PetAdoptionPage extends StatefulWidget {
  const PetAdoptionPage({super.key});

  @override
  State<PetAdoptionPage> createState() => _PetAdoptionPageState();
}

class _PetAdoptionPageState extends State<PetAdoptionPage> {
  String _selectedState = 'All States';
  String _selectedType = 'All Types';
  bool _isLoading = true;

  List<Map<String, dynamic>> _displayedPets = [];
  List<String> _adoptedPetNames = [];

  final List<String> _malaysiaStates = [
    'All States',
    'W.P. Kuala Lumpur',
    'Selangor',
    'Johor',
    'Pulau Pinang',
    'Perak',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Kedah',
    'Kelantan',
    'Terengganu',
    'Sabah',
    'Sarawak',
  ];

  final List<String> _animalTypes = ['All Types', 'Dog', 'Cat', 'Rabbit'];

  final List<Map<String, dynamic>> _allPets = [
    {
      'id': 'p1', 'name': 'Ginger', 'type': 'Cat', 'arrivalDate': '23rd Aug 2026', 'age': '1 Year', 'gender': 'Female',
      'breed': 'Domestic Short Hair', 'health': 'Spayed, Vaccinated, Dewormed', 'state': 'Pulau Pinang', 'location': 'Georgetown, Penang',
      'about': 'A sweet and affectionate ginger cat looking for a loving home. Friendly, energetic, and completely litter-trained.',
      'photoUrl': 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=500&q=80',
    },
    {
      'id': 'p2', 'name': 'Buster', 'type': 'Dog', 'arrivalDate': '21st Aug 2026', 'age': '2 Years', 'gender': 'Male',
      'breed': 'Local Mongrel / Pariah', 'health': 'Vaccinated, Dewormed', 'state': 'Johor', 'location': 'Johor Bahru, Johor',
      'about': 'Rescued locally. Extremely loyal, smart, and protective. Great watch dog companion.',
      'photoUrl': 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500&q=80',
    },
    {
      'id': 'p3', 'name': 'Thumper', 'type': 'Rabbit', 'arrivalDate': '15th Aug 2026', 'age': '8 Months', 'gender': 'Female',
      'breed': 'Netherland Dwarf', 'health': 'Dewormed', 'state': 'Selangor', 'location': 'Petaling Jaya, Selangor',
      'about': 'Quiet, litter-trained indoor bunny who loves munching on fresh carrots and Timothy hay. Requires a calm household.',
      'photoUrl': 'https://images.unsplash.com/photo-1585110396000-c9ffd4e4b308?w=500&q=80',
    },
    {
      'id': 'p4', 'name': 'Luni', 'type': 'Cat', 'arrivalDate': '20th Aug 2026', 'age': '6 Months', 'gender': 'Female',
      'breed': 'Domestic Shorthair', 'health': 'Vaccinated, Dewormed', 'state': 'W.P. Kuala Lumpur', 'location': 'Bangsar, Kuala Lumpur',
      'about': 'Calm, affectionate lap cat who gets along great with other gentle cats and humans. Very well-behaved indoors.',
      'photoUrl': 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=500&q=80',
    },
    {
      'id': 'p5', 'name': 'Max', 'type': 'Dog', 'arrivalDate': '18th Aug 2026', 'age': '1 Year', 'gender': 'Male',
      'breed': 'Golden Retriever Mix', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Selangor', 'location': 'Klang, Selangor',
      'about': 'Friendly, energetic, and loves playing fetch outdoors. Excellent with kids and looking for an active family.',
      'photoUrl': 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=500&q=80',
    },
    {
      'id': 'p6', 'name': 'Mochi', 'type': 'Rabbit', 'arrivalDate': '10th Aug 2026', 'age': '1 Year', 'gender': 'Male',
      'breed': 'Holland Lop', 'health': 'Dewormed', 'state': 'Pulau Pinang', 'location': 'Bayan Lepas, Penang',
      'about': 'Adorable floppy ears. Very friendly and loves being pet. Needs a diet rich in hay.',
      'photoUrl': 'https://cdn.creatures.com/ee0/f91/268/8cb7a.jpeg',
    },
    {
      'id': 'p7', 'name': 'Oreo', 'type': 'Cat', 'arrivalDate': '14th Aug 2026', 'age': '2 Years', 'gender': 'Male',
      'breed': 'Tuxedo Cat', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Melaka', 'location': 'Ayer Keroh, Melaka',
      'about': 'A beautiful tuxedo cat who loves lounging by the window. Very independent but enjoys head scratches.',
      'photoUrl': 'https://www.catster.com/wp-content/uploads/2023/11/tuxedo-cat-with-yellow-eyes_Rosalia-Ricotta_Pixabay.jpg',
    },
    {
      'id': 'p8', 'name': 'Bella', 'type': 'Dog', 'arrivalDate': '10th Aug 2026', 'age': '3 Years', 'gender': 'Female',
      'breed': 'Poodle Mix', 'health': 'Spayed, Vaccinated, Microchipped', 'state': 'Sabah', 'location': 'Kota Kinabalu, Sabah',
      'about': 'Sweet-natured poodle mix. She is highly trainable and loves learning new tricks. Does not shed much.',
      'photoUrl': 'https://images.unsplash.com/photo-1517849845537-4d257902454a?w=500&q=80',
    },
    {
      'id': 'p9', 'name': 'Snowball', 'type': 'Rabbit', 'arrivalDate': '5th Aug 2026', 'age': '2 Months', 'gender': 'Female',
      'breed': 'Lionhead Mix', 'health': 'Dewormed', 'state': 'Johor', 'location': 'Skudai, Johor',
      'about': 'Tiny, fluffy, and very curious. Currently being handled daily to ensure she grows up tame and friendly.',
      'photoUrl': 'https://images.unsplash.com/photo-1518796745738-41048802f99a?w=500&q=80',
    },
    {
      'id': 'p10', 'name': 'Simba', 'type': 'Cat', 'arrivalDate': '8th Aug 2026', 'age': '1 Year', 'gender': 'Male',
      'breed': 'Maine Coon Mix', 'health': 'Vaccinated, Dewormed', 'state': 'Perak', 'location': 'Ipoh, Perak',
      'about': 'A large, fluffy boy with a gentle giant personality. Gets along well with dogs and children.',
      'photoUrl': 'https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=500&q=80',
    },
    {
      'id': 'p11', 'name': 'Kopi', 'type': 'Dog', 'arrivalDate': '5th Aug 2026', 'age': '4 Months', 'gender': 'Male',
      'breed': 'Local Mongrel / Pariah', 'health': '1st Vaccine, Dewormed', 'state': 'W.P. Kuala Lumpur', 'location': 'Cheras, KL',
      'about': 'Found wandering near a coffee shop. Super playful pup looking for his forever home. Needs potty training.',
      'photoUrl': 'https://www.dogpackapp.com/blog/wp-content/uploads/2025/02/indian-pariah-dog-city-street.webp',
    },
    {
      'id': 'p12', 'name': 'Clover', 'type': 'Rabbit', 'arrivalDate': '2nd Aug 2026', 'age': '1.5 Years', 'gender': 'Female',
      'breed': 'Mini Rex', 'health': 'Spayed, Dewormed', 'state': 'Sarawak', 'location': 'Kuching, Sarawak',
      'about': 'Has incredibly soft, velvet-like fur. She is very gentle and prefers quiet environments.',
      'photoUrl': 'https://i.pinimg.com/originals/5d/1e/8c/5d1e8c85f144e6bb64979478f207d5ff.jpg',
    },
    {
      'id': 'p13', 'name': 'Koko', 'type': 'Cat', 'arrivalDate': '20th Aug 2026', 'age': '1 Year', 'gender': 'Male',
      'breed': 'Domestic Short Hair', 'health': 'Vaccinated, Dewormed', 'state': 'W.P. Kuala Lumpur', 'location': 'Kepong, KL',
      'about': 'Very playful and loves feather toys. Needs a home with lots of vertical spaces to climb.',
      'photoUrl': 'https://wallpapercave.com/wp/wp14172398.jpg',
    },
    {
      'id': 'p14', 'name': 'Sparky', 'type': 'Dog', 'arrivalDate': '18th Aug 2026', 'age': '2 Years', 'gender': 'Male',
      'breed': 'Jack Russell Terrier Mix', 'health': 'Neutered, Vaccinated', 'state': 'W.P. Kuala Lumpur', 'location': 'Cheras, KL',
      'about': 'High energy and incredibly smart. Requires an active owner who can take him on daily runs.',
      'photoUrl': 'https://i.pinimg.com/originals/e8/10/4f/e8104f8b0064d3e105d47f4769224618.jpg',
    },
    {
      'id': 'p15', 'name': 'Mimi', 'type': 'Rabbit', 'arrivalDate': '15th Aug 2026', 'age': '6 Months', 'gender': 'Female',
      'breed': 'Netherland Dwarf', 'health': 'Dewormed', 'state': 'Selangor', 'location': 'Subang Jaya, Selangor',
      'about': 'Shy at first but warms up quickly with treats. Fully litter box trained.',
      'photoUrl': 'https://image.petmd.com/files/styles/863x625/public/2023-08/netherland.dwarf_.jpg',
    },
    {
      'id': 'p16', 'name': 'Rocky', 'type': 'Dog', 'arrivalDate': '10th Aug 2026', 'age': '3 Years', 'gender': 'Male',
      'breed': 'Local Mongrel / Pariah', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Selangor', 'location': 'Petaling Jaya, Selangor',
      'about': 'A gentle giant who gets along well with other dogs and kids. Very food motivated.',
      'photoUrl': 'https://www.dogbible.com/_ipx/f_jpeg,q_80,fit_cover,s_544x544/dogbible/i/en/pariahund-india-black.jpg',
    },
    {
      'id': 'p17', 'name': 'Lulu', 'type': 'Cat', 'arrivalDate': '21st Aug 2026', 'age': '2 Years', 'gender': 'Female',
      'breed': 'Persian Mix', 'health': 'Spayed, Vaccinated', 'state': 'Johor', 'location': 'Skudai, Johor',
      'about': 'A quiet lap cat who enjoys daily grooming. Best suited for a calm, indoor-only environment.',
      'photoUrl': 'https://i.pinimg.com/originals/ed/84/2f/ed842fb51ab4c91f2afbd49951a17b90.jpg',
    },
    {
      'id': 'p18', 'name': 'Milo', 'type': 'Dog', 'arrivalDate': '5th Aug 2026', 'age': '8 Months', 'gender': 'Male',
      'breed': 'Golden Retriever Mix', 'health': 'Vaccinated, Dewormed', 'state': 'Johor', 'location': 'Batu Pahat, Johor',
      'about': 'Goofy puppy still learning his manners. Will thrive with positive reinforcement training.',
      'photoUrl': 'https://www.bubblypet.com/wp-content/uploads/2022/11/Golden-Retriever-mixes-and-mixed-breeds-with-pictures-2048x1366.jpg',
    },
    {
      'id': 'p19', 'name': 'Nala', 'type': 'Cat', 'arrivalDate': '14th Aug 2026', 'age': '1.5 Years', 'gender': 'Female',
      'breed': 'Calico', 'health': 'Spayed, Vaccinated, Dewormed', 'state': 'Pulau Pinang', 'location': 'Bayan Lepas, Penang',
      'about': 'Independent and curious. She loves watching birds from the window for hours.',
      'photoUrl': 'https://scanner.siwalusoftware.com/breed_images/cat/calico_cat/calico_cat.jpg',
    },
    {
      'id': 'p20', 'name': 'Coco', 'type': 'Rabbit', 'arrivalDate': '12th Aug 2026', 'age': '1 Year', 'gender': 'Male',
      'breed': 'Mini Lop', 'health': 'Neutered, Dewormed', 'state': 'Pulau Pinang', 'location': 'Butterworth, Penang',
      'about': 'Friendly bunny who loves to binky around the living room. Great with gentle children.',
      'photoUrl': 'https://i.pinimg.com/originals/1a/d1/68/1ad168e935c23ab5318077e40e357324.jpg',
    },
    {
      'id': 'p21', 'name': 'Max', 'type': 'Dog', 'arrivalDate': '8th Aug 2026', 'age': '4 Years', 'gender': 'Male',
      'breed': 'German Shepherd Mix', 'health': 'Neutered, Vaccinated', 'state': 'Perak', 'location': 'Ipoh, Perak',
      'about': 'Loyal and protective. Makes an excellent guard dog but is a total softie with his family.',
      'photoUrl': 'https://germanshepherdpuppiesnc.com/wp-content/uploads/2024/03/pitbull-german-shepherd.jpeg',
    },
    {
      'id': 'p22', 'name': 'Cleo', 'type': 'Cat', 'arrivalDate': '22nd Aug 2026', 'age': '2 Years', 'gender': 'Female',
      'breed': 'Siamese Mix', 'health': 'Spayed, Vaccinated, Dewormed', 'state': 'Perak', 'location': 'Taiping, Perak',
      'about': 'Very vocal and loves to have conversations with her humans. Seeks constant affection.',
      'photoUrl': 'https://www.catster.com/wp-content/uploads/1970/01/Siamese-and-Ragdoll-Mixed-Cat-Lounging-on-Window-Sill_Laura-Drake-Enberg-Shutterstock.jpg',
    },
    {
      'id': 'p23', 'name': 'Hazel', 'type': 'Rabbit', 'arrivalDate': '17th Aug 2026', 'age': '5 Months', 'gender': 'Female',
      'breed': 'Lionhead', 'health': 'Dewormed', 'state': 'Melaka', 'location': 'Alor Gajah, Melaka',
      'about': 'Needs daily brushing for her magnificent mane. Very sweet and gentle disposition.',
      'photoUrl': 'https://cdn.creatures.com/479/b58/c47/a7447.jpeg',
    },
    {
      'id': 'p24', 'name': 'Toby', 'type': 'Dog', 'arrivalDate': '2nd Aug 2026', 'age': '1 Year', 'gender': 'Male',
      'breed': 'Terrier Mix', 'health': 'Neutered, Vaccinated', 'state': 'Melaka', 'location': 'Jasin, Melaka',
      'about': 'Scruffy, small-sized dog perfect for apartment living. Does not shed very much.',
      'photoUrl': 'https://cdn.pixabay.com/photo/2012/02/17/15/24/dog-14460_1280.jpg',
    },
    {
      'id': 'p25', 'name': 'Simba', 'type': 'Cat', 'arrivalDate': '9th Aug 2026', 'age': '3 Years', 'gender': 'Male',
      'breed': 'Maine Coon Mix', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Negeri Sembilan', 'location': 'Seremban, Negeri Sembilan',
      'about': 'A large, fluffy boy with a gentle giant personality. Gets along well with dogs.',
      'photoUrl': 'https://i.pinimg.com/originals/ab/90/8b/ab908bc65f9c278c7c79f438a1e22261.jpg',
    },
    {
      'id': 'p26', 'name': 'Daisy', 'type': 'Dog', 'arrivalDate': '11th Aug 2026', 'age': '2 Years', 'gender': 'Female',
      'breed': 'Poodle Mix', 'health': 'Spayed, Vaccinated', 'state': 'Negeri Sembilan', 'location': 'Nilai, Negeri Sembilan',
      'about': 'Hypoallergenic coat and very eager to please. Already knows basic commands like sit and stay.',
      'photoUrl': 'https://images.saymedia-content.com/.image/t_share/MTg3MDE1ODE2ODA0NzcwODI3/oodles-of-doodles-the-best-poodle-mixed-dog-breeds.jpg',
    },
    {
      'id': 'p27', 'name': 'Buddy', 'type': 'Dog', 'arrivalDate': '1st Aug 2026', 'age': '5 Years', 'gender': 'Male',
      'breed': 'Local Mongrel / Pariah', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Pahang', 'location': 'Kuantan, Pahang',
      'about': 'A senior dog looking for a quiet retirement home to nap in the sun. Very low maintenance.',
      'photoUrl': 'https://thumbs.dreamstime.com/b/beautiful-street-dog-very-cute-dogs-known-scientific-literature-as-free-ranging-urban-unconfined-live-cities-269275854.jpg',
    },
    {
      'id': 'p28', 'name': 'Snow', 'type': 'Rabbit', 'arrivalDate': '19th Aug 2026', 'age': '1 Year', 'gender': 'Female',
      'breed': 'New Zealand White', 'health': 'Dewormed', 'state': 'Pahang', 'location': 'Bentong, Pahang',
      'about': 'Larger breed rabbit with beautiful red eyes. Prefers roaming free in a rabbit-proofed room.',
      'photoUrl': 'https://res.cloudinary.com/petrescue/image/upload/v1621991972/juoahyoa5r1hto1xger1.jpg',
    },
    {
      'id': 'p29', 'name': 'Tiger', 'type': 'Cat', 'arrivalDate': '13th Aug 2026', 'age': '8 Months', 'gender': 'Male',
      'breed': 'Tabby', 'health': 'Vaccinated, Dewormed', 'state': 'Kedah', 'location': 'Sungai Petani, Kedah',
      'about': 'A mischievous teenager who loves chasing laser pointers and playing with crumpled paper.',
      'photoUrl': 'https://moderncat.com/wp-content/uploads/2024/10/BrownCats_ss_1475286827_Krakenimages.com_.jpg',
    },
    {
      'id': 'p30', 'name': 'Bella', 'type': 'Dog', 'arrivalDate': '6th Aug 2026', 'age': '3 Years', 'gender': 'Female',
      'breed': 'Schnauzer Mix', 'health': 'Spayed, Vaccinated, Microchipped', 'state': 'Kedah', 'location': 'Alor Setar, Kedah',
      'about': 'Alert and very loyal to her chosen person. Takes a little time to warm up to strangers.',
      'photoUrl': 'https://happydogbreeds.com/wp-content/uploads/2023/07/Border-Schnollie-Border-Collie-Standard-Schnauzer-mix.jpg',
    },
    {
      'id': 'p31', 'name': 'Thumper', 'type': 'Rabbit', 'arrivalDate': '20th Aug 2026', 'age': '1.5 Years', 'gender': 'Male',
      'breed': 'Dutch Rabbit', 'health': 'Neutered, Dewormed', 'state': 'Kelantan', 'location': 'Kota Bharu, Kelantan',
      'about': 'Has a striking tuxedo-like coat. Loves eating fresh herbs and lounging under the sofa.',
      'photoUrl': 'https://alchetron.com/cdn/dutch-rabbit-d60a9af4-3a80-441d-87d7-c07af4ae103-resize-750.jpg',
    },
    {
      'id': 'p32', 'name': 'Luna', 'type': 'Cat', 'arrivalDate': '4th Aug 2026', 'age': '2 Years', 'gender': 'Female',
      'breed': 'Domestic Shorthair', 'health': 'Spayed, Vaccinated', 'state': 'Kelantan', 'location': 'Pasir Mas, Kelantan',
      'about': 'A former stray who has fully embraced indoor luxury. Will purr loudly the moment you touch her.',
      'photoUrl': 'https://cdn.pixabay.com/photo/2023/07/12/07/07/cat-8121892_1280.jpg',
    },
    {
      'id': 'p33', 'name': 'Duke', 'type': 'Dog', 'arrivalDate': '7th Aug 2026', 'age': '4 Years', 'gender': 'Male',
      'breed': 'Rottweiler Mix', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Terengganu', 'location': 'Kuala Terengganu, Terengganu',
      'about': 'Big and strong, but thinks he is a lap dog. Needs a confident handler and secure fencing.',
      'photoUrl': 'https://cdn.shopify.com/s/files/1/0265/6157/7032/files/Rottweiler-dog.jpg?v=1693825225',
    },
    {
      'id': 'p34', 'name': 'Chloe', 'type': 'Cat', 'arrivalDate': '16th Aug 2026', 'age': '1 Year', 'gender': 'Female',
      'breed': 'Tuxedo Cat', 'health': 'Spayed, Vaccinated, Dewormed', 'state': 'Terengganu', 'location': 'Dungun, Terengganu',
      'about': 'Playful and graceful. Always dressed to impress in her little tuxedo suit.',
      'photoUrl': 'https://wallpapers.com/images/hd/tuxedo-cat-pictures-2000-x-1333-tkckhpba5rojoq3x.jpg',
    },
    {
      'id': 'p35', 'name': 'Leo', 'type': 'Cat', 'arrivalDate': '21st Aug 2026', 'age': '3 Years', 'gender': 'Male',
      'breed': 'Bengal Mix', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Sabah', 'location': 'Kota Kinabalu, Sabah',
      'about': 'Very active and athletic. Requires lots of stimulation and playtime to stay happy.',
      'photoUrl': 'https://bloggingwithconnie.com/wp-content/uploads/2024/06/13594493-1-1024x750.jpg',
    },
    {
      'id': 'p36', 'name': 'Molly', 'type': 'Dog', 'arrivalDate': '15th Aug 2026', 'age': '2 Years', 'gender': 'Female',
      'breed': 'Corgi Mix', 'health': 'Spayed, Vaccinated', 'state': 'Sabah', 'location': 'Sandakan, Sabah',
      'about': 'Short legs but a big personality! Very social and loves meeting new people at the park.',
      'photoUrl': 'https://hips.hearstapps.com/hmg-prod/images/niko-royalty-free-image-1726720063.jpg?crop=0.66682xw:1xh;center,top&resize=980:*',
    },
    {
      'id': 'p37', 'name': 'Bunbun', 'type': 'Rabbit', 'arrivalDate': '12th Aug 2026', 'age': '9 Months', 'gender': 'Male',
      'breed': 'Rex Rabbit', 'health': 'Dewormed', 'state': 'Sarawak', 'location': 'Kuching, Sarawak',
      'about': 'Has incredibly soft, velvet-like fur. He is very gentle and prefers quiet environments.',
      'photoUrl': 'https://media-be.chewy.com/wp-content/uploads/mini-rex-main.jpg',
    },
    {
      'id': 'p38', 'name': 'Jack', 'type': 'Dog', 'arrivalDate': '3rd Aug 2026', 'age': '1.5 Years', 'gender': 'Male',
      'breed': 'Local Mongrel / Pariah', 'health': 'Neutered, Vaccinated, Dewormed', 'state': 'Sarawak', 'location': 'Miri, Sarawak',
      'about': 'Found abandoned, but has retained a joyful spirit. Very intelligent and learns tricks quickly.',
      'photoUrl': 'https://blog.unleavables.com/wp-content/uploads/2025/05/WhatsApp-Image-2025-05-04-at-20.32.54_67fce629-1024x950.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAdoptedPetsAndFilter();
  }

  Future<void> _loadAdoptedPetsAndFilter() async {
    setState(() => _isLoading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    _adoptedPetNames.clear();

    if (uid != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('pets')
            .where('uid', isEqualTo: uid)
            .where('isAdopted', isEqualTo: true)
            .get();
        for (final doc in snap.docs) {
          final name = doc.data()['name'];
          if (name != null) _adoptedPetNames.add(name);
        }
      } catch (_) {
        // Leave the catalog unfiltered if Firestore is briefly unreachable,
        // rather than blocking browsing entirely.
      }
    }

    _applyFilterAndSearch();
    setState(() => _isLoading = false);
  }

  void _applyFilterAndSearch() {
    List<Map<String, dynamic>> results = _allPets.where((p) {
      return !_adoptedPetNames.contains(p['name']);
    }).toList();

    if (_selectedState != 'All States') {
      results = results.where((p) => p['state'] == _selectedState).toList();
    }

    if (_selectedType != 'All Types') {
      results = results.where((p) => p['type'] == _selectedType).toList();
    }

    setState(() {
      _displayedPets = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = isDark ? Colors.white : Colors.brown[800]!;
    final Color cardBackground = isDark ? Colors.grey[850]! : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verified Pet Adoptions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cardBackground,
                  border: Border.all(color: primaryColor, width: 1.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedState,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                    dropdownColor: cardBackground,
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                    items: _malaysiaStates.map((state) {
                      return DropdownMenuItem<String>(value: state, child: Text(state));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedState = val);
                        _applyFilterAndSearch();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _animalTypes.map((type) {
                    final isSelected = _selectedType == type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        backgroundColor: cardBackground,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? (isDark ? Colors.brown[900]! : Colors.white) : primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedType = type;
                            _applyFilterAndSearch();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryColor),
                      const SizedBox(height: 16),
                      Text('Loading pets...', style: TextStyle(color: primaryColor)),
                    ],
                  ),
                )
                    : _displayedPets.isEmpty
                    ? Center(
                  child: Text(
                    'No pets available for adoption based on your filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                )
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _displayedPets.length,
                  itemBuilder: (context, index) {
                    final pet = _displayedPets[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: cardBackground,
                        border: Border.all(color: primaryColor, width: 1.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PetDetailsAndAdoptionPage(petData: pet),
                            ),
                          ).then((_) {
                            _loadAdoptedPetsAndFilter();
                          });
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                              child: SizedBox(
                                width: 100,
                                height: 100,
                                child: Image.network(
                                  pet['photoUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.brown[100],
                                      child: Icon(Icons.pets, color: Colors.brown[800], size: 36),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Container(
                              width: 1.8,
                              height: 100,
                              color: primaryColor,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            pet['name'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${pet['gender']} • ${pet['age']}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pet['breed'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey[300] : Colors.brown[700],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            pet['location'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}