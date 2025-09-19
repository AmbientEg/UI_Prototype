import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_text_styles.dart';
import '../models/kalman_filter.dart';

class BeaconsItem extends StatefulWidget {
  final List<ScanResult> devices;

   BeaconsItem({super.key, required this.devices});

  @override
  State<BeaconsItem> createState() => _BeaconsItemState();
}

class _BeaconsItemState extends State<BeaconsItem> {
  final KalmanFilter kf = KalmanFilter(0);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.devices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final device = widget.devices[index];



          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.navyColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryGrey, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.bluetooth, color: AppColors.lightCyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    device.device.platformName.isNotEmpty
                        ? device.device.platformName
                        : "Unknown device",
                    style: AppTextStyles.bold20cyan,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text("${device.rssi} dBm",
                    style: AppTextStyles.bold20cyan),
                const SizedBox(width: 10),
                Text(
                  "${kf.filter(device.rssi.toDouble())} dBm kalman",
                  style: AppTextStyles.bold20cyan,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

