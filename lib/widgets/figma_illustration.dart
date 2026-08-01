import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class IllustrationLayer {
  const IllustrationLayer(
    this.asset,
    this.left,
    this.top,
    this.width,
    this.height,
  );

  final String asset;
  final double left;
  final double top;
  final double width;
  final double height;
}

/// Reconstructs a multi-layer Figma illustration (unDraw-style onboarding art)
/// by stacking its exported SVG layers at their original relative positions.
class FigmaIllustration extends StatelessWidget {
  const FigmaIllustration({
    super.key,
    required this.width,
    required this.height,
    required this.layers,
  });

  final double width;
  final double height;
  final List<IllustrationLayer> layers;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: width / height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / width;
          return Stack(
            children: [
              for (final layer in layers)
                Positioned(
                  left: layer.left * scale,
                  top: layer.top * scale,
                  width: layer.width * scale,
                  height: layer.height * scale,
                  child: SvgPicture.asset(layer.asset, fit: BoxFit.fill),
                ),
            ],
          );
        },
      ),
    );
  }
}

const onboarding1Illustration = FigmaIllustration(
  width: 347.02,
  height: 219.05,
  layers: [
    IllustrationLayer(
      'assets/images/ob1_bg_complete.svg',
      0,
      0,
      346.31,
      218.79,
    ),
    IllustrationLayer(
      'assets/images/ob1_bg_simple.svg',
      20.55,
      17.30,
      305.24,
      133.00,
    ),
    IllustrationLayer(
      'assets/images/ob1_plants.svg',
      2.36,
      189.66,
      344.66,
      29.14,
    ),
    IllustrationLayer(
      'assets/images/ob1_lines.svg',
      74.08,
      70.03,
      142.86,
      15.42,
    ),
    IllustrationLayer('assets/images/ob1_car.svg', 5.93, 85.20, 334.52, 133.59),
    IllustrationLayer(
      'assets/images/ob1_character.svg',
      52.94,
      36.89,
      72.74,
      181.90,
    ),
    IllustrationLayer(
      'assets/images/ob1_floor.svg',
      4.32,
      218.54,
      337.70,
      0.51,
    ),
  ],
);

const onboarding2Illustration = FigmaIllustration(
  width: 355.00,
  height: 220.50,
  layers: [
    IllustrationLayer(
      'assets/images/ob2_bg_complete.svg',
      2.71,
      0,
      344.98,
      179.01,
    ),
    IllustrationLayer(
      'assets/images/ob2_bg_simple.svg',
      75.65,
      2.81,
      220.12,
      183.95,
    ),
    IllustrationLayer(
      'assets/images/ob2_characters.svg',
      39.46,
      25.13,
      300.02,
      195.36,
    ),
    IllustrationLayer('assets/images/ob2_floor.svg', 0, 220.07, 355.00, 0.26),
  ],
);

const onboarding3Illustration = FigmaIllustration(
  width: 355.00,
  height: 239.75,
  layers: [
    IllustrationLayer(
      'assets/images/ob3_bg_complete.svg',
      0,
      14.23,
      355.00,
      225.01,
    ),
    IllustrationLayer(
      'assets/images/ob3_bg_simple.svg',
      49.75,
      18.83,
      282.57,
      177.22,
    ),
    IllustrationLayer(
      'assets/images/ob3_device.svg',
      164.90,
      0,
      108.98,
      239.16,
    ),
    IllustrationLayer(
      'assets/images/ob3_character.svg',
      89.29,
      35.78,
      153.35,
      203.03,
    ),
    IllustrationLayer(
      'assets/images/ob3_plant.svg',
      50.74,
      212.57,
      19.61,
      26.67,
    ),
    IllustrationLayer(
      'assets/images/ob3_ball.svg',
      232.97,
      197.15,
      42.52,
      42.60,
    ),
    IllustrationLayer(
      'assets/images/ob3_floor.svg',
      8.61,
      239.07,
      345.45,
      0.26,
    ),
  ],
);
