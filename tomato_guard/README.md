# Tomato Guard 🍅🍃

**Tomato Guard** is a complete, modern Flutter mobile application designed for real-time Tomato Plant Disease Detection, featuring LADA image enhancement, AI classification, treatment recommendations, and leaf disease spot segmentation/severity analysis.

---

## 🌟 Key Features

1. **Modern Green Material 3 Design**:
   - Primary palette (`#2E7D32`, `#43A047`, `#66BB6A`)
   - Soft white card surfaces with rounded corners (20-24px radius)
   - Custom leaf branding and crisp typography (Google Fonts Inter & Poppins)

2. **Full Application Flow**:
   - **Home Screen**: App title, leaf branding, Camera & Gallery pickers (`image_picker`), and preset sample leaf option.
   - **Image Preview Screen**: Preview selected leaf image with two options:
     - **Option 1 ("Enhance with LADA")**: Simulates Spatial-Linear Augmentation & Cross-Channel Attention feature enhancement, shows loading progress indicator, displays "Enhanced by LADA" badge, and forwards the enhanced image to classification.
     - **Option 2 ("Classify Directly")**: Bypasses LADA enhancement and classifies the original image directly.
   - **Classification Page**: Displays the exact image used (Original vs LADA Enhanced badge), predicted disease diagnosis (e.g. *Tomato Early Blight*), confidence percentage gauge, and action buttons.
   - **Treatment Recommendation Page**: Categorized treatment recommendations:
     - Cultural Practices
     - Organic Treatments
     - Chemical Treatments
   - **Segmentation & Severity Estimation Page**: Visual leaf disease spot green mask overlay, Severity grade (Mild / Moderate / Severe), affected leaf surface area %, and morphological lesion analysis.

---

## 📁 Clean Architecture & Folder Structure

```
tomato_guard/
├── pubspec.yaml
├── README.md
└── lib/
    ├── main.dart                      # App entrypoint
    ├── theme/
    │   └── app_theme.dart             # Material 3 Green Theme system
    ├── models/
    │   ├── disease_result.dart        # Classification output model
    │   ├── treatment_info.dart        # Cultural, Organic, & Chemical treatment model
    │   └── severity_result.dart       # Severity & segmentation metrics model
    ├── services/
    │   ├── lada_service.dart          # LADA image enhancement pipeline service
    │   └── disease_service.dart       # PlantVillage disease classification engine
    ├── widgets/
    │   ├── custom_button.dart         # Primary and secondary green buttons
    │   ├── badge_chip.dart            # "Enhanced by LADA" and severity level chips
    │   ├── image_card.dart            # Image container card with badge overlays
    │   ├── section_header.dart        # Accent header widget
    │   └── segmented_image_view.dart  # Custom painter for disease spot green mask
    └── screens/
        ├── home_screen.dart           # Step 1: Home & Camera/Gallery picking
        ├── image_preview_screen.dart  # Step 2 & 3: LADA processing & option selection
        ├── classification_screen.dart # Step 5: Disease prediction & confidence %
        ├── treatment_screen.dart      # Step 6: Detailed treatment recommendations
        └── segmentation_screen.dart   # Step 7: Green overlay & severity estimation
```

---

## 🚀 Running the Flutter App

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK

### Installation & Execution
```bash
# Navigate to the project directory
cd tomato_guard

# Fetch dependencies
flutter pub get

# Run on emulator/connected device
flutter run
```
