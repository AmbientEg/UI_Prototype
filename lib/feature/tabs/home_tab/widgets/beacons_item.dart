import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/app_text_styles.dart';

class BeaconsItem extends StatelessWidget {
  const BeaconsItem({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      child: ListView.separated(
        physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 20),
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.navyColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryGrey, width: 1),
              ),
              child: Row(
                children: [
                  SizedBox(width: 10),
                  Icon(Icons.wifi, color: AppColors.lightCyan),
                  SizedBox(width: 10),
                  Text("Beacon ${index + 1}", style: AppTextStyles.bold20cyan),
                  Spacer(),
                  Text("-78 Dbm", style: AppTextStyles.bold20cyan),

                ],
              ),
            );
          },
          separatorBuilder: (context, index) {
            return SizedBox(height:10);
          },
          itemCount: 5
      ),
    );
  }
}
