import 'package:flutter/material.dart';

import '../../domain/usecases/auth_use_cases.dart';
import '../../domain/usecases/course_use_cases.dart';
import '../../domain/usecases/task_use_cases.dart';
import '../announcements/announcements_screen.dart';
import 'upcoming_notifications_screen.dart';

class CommunicationsScreen extends StatelessWidget {
  final TaskUseCases taskUseCases;
  final CourseUseCases courseUseCases;
  final AuthUseCases authUseCases;

  const CommunicationsScreen({
    super.key,
    required this.taskUseCases,
    required this.courseUseCases,
    required this.authUseCases,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'الإشعارات والتعميمات' : 'Notifications & Announcements'),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.notifications_outlined),
                text: isArabic ? 'الإشعارات' : 'Notifications',
              ),
              Tab(
                icon: const Icon(Icons.campaign_outlined),
                text: isArabic ? 'التعميمات' : 'Announcements',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            UpcomingNotificationsScreen(
              taskUseCases: taskUseCases,
              courseUseCases: courseUseCases,
              embedded: true,
            ),
            AnnouncementsScreen(
              authUseCases: authUseCases,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}
