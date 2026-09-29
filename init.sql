CREATE DATABASE IF NOT EXISTS routesafe_db;
USE routesafe_db;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS `assignment_logs`;
CREATE TABLE `assignment_logs` (
  `log_id` int(11) NOT NULL AUTO_INCREMENT,
  `entity_type` varchar(50) NOT NULL,
  `entity_id` int(11) DEFAULT NULL,
  `action` varchar(50) NOT NULL,
  `details` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`log_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

DROP TABLE IF EXISTS `buses`;
CREATE TABLE `buses` (
  `bus_id` int(11) NOT NULL AUTO_INCREMENT,
  `bus_number` varchar(50) NOT NULL,
  `registration_number` varchar(50) DEFAULT NULL,
  `route` varchar(150) NOT NULL,
  `driver_name` varchar(100) DEFAULT NULL,
  `status` varchar(20) DEFAULT 'Active',
  `start_point` varchar(100) DEFAULT NULL,
  `destination` varchar(100) DEFAULT NULL,
  `driver_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`bus_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `buses` (`bus_id`, `bus_number`, `registration_number`, `route`, `driver_name`, `status`, `start_point`, `destination`, `driver_id`, `created_at`) VALUES
(3, '11', NULL, 'Chengannur', 'Quality Driver 1790012468019', 'Active', NULL, NULL, 62, '2026-07-26 22:27:08'),
(4, '12', NULL, 'Pala', 'Anil', 'Active', NULL, NULL, 8, '2026-08-09 15:52:39'),
(6, '1', NULL, 'Thiruvalla', 'Benit', 'Active', NULL, NULL, 40, '2026-09-13 21:31:07'),
(7, '10', NULL, 'Chengannur', 'Ben', 'Active', NULL, NULL, 6, '2026-09-20 20:27:38'),
(8, '14', 'KL-05-AB-1414', 'Kottayam', 'Soman', 'Active', NULL, NULL, 66, '2026-09-22 14:46:49');

DROP TABLE IF EXISTS `driver_emergencies`;
CREATE TABLE `driver_emergencies` (
  `emergency_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `emergency_type` varchar(50) DEFAULT 'Other',
  `message` text NOT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'Pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`emergency_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `driver_emergencies` (`emergency_id`, `driver_id`, `emergency_type`, `message`, `latitude`, `longitude`, `bus_id`, `status`, `created_at`) VALUES
(1, 39, 'Vehicle Breakdown', 'Engine issue near Stop 2', 10.0123, 76.3456, 3, 'Pending', '2026-09-14 21:29:16');

DROP TABLE IF EXISTS `driver_locations`;
CREATE TABLE `driver_locations` (
  `location_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`location_id`)
) ENGINE=InnoDB AUTO_INCREMENT=61 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `driver_locations` (`location_id`, `driver_id`, `latitude`, `longitude`, `updated_at`) VALUES
(1, 8, '9.3151000', '76.6151000', '2026-09-01 20:31:07'),
(2, 8, '9.3151000', '76.6151000', '2026-09-01 20:31:54'),
(3, 8, '9.3175000', '76.6150000', '2026-09-08 10:39:26'),
(4, 8, '9.3175000', '76.6150000', '2026-09-08 10:54:43'),
(5, 8, '9.3175000', '76.6150000', '2026-09-08 10:55:10'),
(6, 8, '9.3175000', '76.6150000', '2026-09-08 10:55:38'),
(7, 8, '9.3175000', '76.6150000', '2026-09-13 21:10:47'),
(8, 8, '9.3175000', '76.6150000', '2026-09-13 21:29:37'),
(9, 8, '9.3175000', '76.6150000', '2026-09-13 22:09:36'),
(10, 8, '9.3175000', '76.6150000', '2026-09-13 22:17:04'),
(11, 39, '10.0123000', '76.3456000', '2026-09-14 21:29:16'),
(12, 40, '9.3175000', '76.6150000', '2026-09-16 06:26:58'),
(13, 40, '9.3175000', '76.6150000', '2026-09-16 06:36:50'),
(14, 40, '9.3175000', '76.6150000', '2026-09-16 09:06:31'),
(15, 40, '9.3175000', '76.6150000', '2026-09-16 09:16:12'),
(16, 40, '9.3175000', '76.6150000', '2026-09-16 09:24:43'),
(17, 40, '9.3175000', '76.6150000', '2026-09-16 10:43:33'),
(18, 40, '9.3175000', '76.6150000', '2026-09-16 10:45:13'),
(19, 40, '9.3175000', '76.6150000', '2026-09-16 10:55:23'),
(20, 40, '9.3175000', '76.6150000', '2026-09-16 10:57:56'),
(21, 40, '9.3175000', '76.6150000', '2026-09-20 19:18:32'),
(22, 40, '9.3217908', '76.6106313', '2026-09-20 19:30:50'),
(23, 40, '9.3217908', '76.6106313', '2026-09-20 19:30:51'),
(24, 40, '9.3218583', '76.6105799', '2026-09-20 19:31:03'),
(25, 40, '9.3218583', '76.6105799', '2026-09-20 19:31:06'),
(26, 40, '9.3219381', '76.6104934', '2026-09-20 19:31:15'),
(27, 40, '9.3219381', '76.6104934', '2026-09-20 19:31:16'),
(28, 40, '9.3220195', '76.6104841', '2026-09-20 19:31:23'),
(29, 40, '9.3175000', '76.6150000', '2026-09-20 19:55:28'),
(30, 47, '9.3175000', '76.6150000', '2026-09-20 22:05:11'),
(31, 40, '9.3217025', '76.6105648', '2026-09-21 20:13:46'),
(32, 40, '9.3217025', '76.6105648', '2026-09-21 20:13:49'),
(33, 40, '9.3218854', '76.6104779', '2026-09-21 20:13:55'),
(34, 40, '9.3218854', '76.6104779', '2026-09-21 20:13:59'),
(35, 40, '9.3218933', '76.6104750', '2026-09-21 20:14:04'),
(36, 40, '9.3218733', '76.6105467', '2026-09-21 20:14:10'),
(37, 40, '9.3218733', '76.6105467', '2026-09-21 20:14:14'),
(38, 40, '9.3218568', '76.6105532', '2026-09-21 20:14:20'),
(39, 40, '9.3218568', '76.6105532', '2026-09-21 20:14:24'),
(40, 40, '9.3218541', '76.6105512', '2026-09-21 20:14:30'),
(41, 40, '9.3218541', '76.6105512', '2026-09-21 20:14:34'),
(42, 40, '9.3218017', '76.6105467', '2026-09-21 20:14:41'),
(43, 40, '9.3218017', '76.6105467', '2026-09-21 20:14:44'),
(44, 40, '9.3217817', '76.6105567', '2026-09-21 20:20:23'),
(45, 40, '9.3217817', '76.6105567', '2026-09-21 20:20:25'),
(46, 40, '9.3217788', '76.6105538', '2026-09-21 20:20:31'),
(47, 40, '9.3217788', '76.6105538', '2026-09-21 20:20:35'),
(48, 40, '9.3216767', '76.6105400', '2026-09-21 20:20:41'),
(49, 49, '9.3175000', '76.6150000', '2026-09-21 20:40:35'),
(50, 40, '9.3217487', '76.6106376', '2026-09-21 20:45:35'),
(51, 51, '9.3175000', '76.6150000', '2026-09-21 21:21:48'),
(52, 53, '9.3175000', '76.6150000', '2026-09-21 21:43:09'),
(53, 55, '9.3175000', '76.6150000', '2026-09-21 22:08:52'),
(54, 57, '9.3175000', '76.6150000', '2026-09-21 22:34:43'),
(55, 59, '9.3175000', '76.6150000', '2026-09-21 22:41:27'),
(56, 62, '9.3175000', '76.6150000', '2026-09-21 23:11:08'),
(57, 40, '9.5104397', '76.5505966', '2026-09-22 11:02:03'),
(58, 40, '9.5104397', '76.5505966', '2026-09-22 11:02:06'),
(59, 40, '9.5104397', '76.5505966', '2026-09-22 11:02:16'),
(60, 40, '9.5104397', '76.5505966', '2026-09-22 11:02:21');

DROP TABLE IF EXISTS `driver_phone_otp`;
CREATE TABLE `driver_phone_otp` (
  `otp_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `new_phone` varchar(20) NOT NULL,
  `otp_hash` varchar(255) NOT NULL,
  `expires_at` datetime NOT NULL,
  `attempts` int(11) DEFAULT 0,
  `verified` tinyint(1) DEFAULT 0,
  `created_at` datetime DEFAULT current_timestamp(),
  PRIMARY KEY (`otp_id`),
  KEY `driver_id` (`driver_id`),
  CONSTRAINT `driver_phone_otp_ibfk_1` FOREIGN KEY (`driver_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `driver_phone_otp` (`otp_id`, `driver_id`, `new_phone`, `otp_hash`, `expires_at`, `attempts`, `verified`, `created_at`) VALUES
(5, 8, '9876543210', 'scrypt:32768:8:1$hQDFtoT0FMDyz0Vk$dc1a1901a656480adb014d0618e628933e7a6dbe3fcdedd163910b65cb233714a39518518385759c3f3251265a7635dd8785eaa236218f71d25c0e73d5e64ba6', '2026-09-08 10:36:24', 2, 1, '2026-09-08 10:31:24'),
(6, 8, '9988776655', 'scrypt:32768:8:1$4onRHMf508BygX8R$1fbde70f374850d7f6739c47e2c44e152495b780c8b6dfb38db0474c845f1d233f18186076787c52715722ccb085b2b8276ef4bf0de802ee5dd3520469454a60', '2026-09-08 10:44:26', 1, 1, '2026-09-08 10:39:26'),
(7, 8, '9788845138', 'scrypt:32768:8:1$Hx3DSYs2qUPQ2Ig8$124842429de58214470a57668d41641077ff20009911499e8ab0d6a1fbcacb71696eb8a5eec74b6afcd47c04cdfe06b19e710e2019b32c24b781e625f95cda20', '2026-09-08 11:00:39', 1, 1, '2026-09-08 10:55:39'),
(8, 8, '9789314047', 'scrypt:32768:8:1$MxpA4IxUKTw13FQI$79169971dff7e9b7e77b44bed8ec637fe4400499cb94b469af7ad8a9941ac2953f568c22be07e93b5a6c937b85bea015304f734ad2f3a21bc435e0f2deb9c94d', '2026-09-13 21:15:47', 1, 1, '2026-09-13 21:10:47'),
(9, 8, '9789315177', 'scrypt:32768:8:1$owkt8fZ2jakQe3OB$9af704256df77a1d371629729ad09d0e5487df5a0e5db2c36fad6c5296058e61a2af98d87216f92f18647b878047066b00eb22ecccd7eeecaa4d173ece2e17c9', '2026-09-13 21:34:38', 1, 1, '2026-09-13 21:29:38'),
(11, 28, '9609364896', 'scrypt:32768:8:1$FOyCVngvQ29WKlxn$563413a00d038193385aaf5f4153c10b220f43b258b713fadd0ac65a5d0a8d08d922deacbb7c214bd2c587cf43b99096183c41c5a606d1704c099ebc33a78c06', '2026-09-13 22:14:23', 1, 1, '2026-09-13 22:09:23'),
(12, 8, '9789317576', 'scrypt:32768:8:1$WbUakS7ZsmR1eDrC$c1b223bdd4c8e4623a6117a625131044d92c3dc0e317e06b0d3771e2c1ed00530bf2939a94e6d9957f5ef4faca8c3c3b5b93f0b474d9de9d17bf15e21eaf9239', '2026-09-13 22:14:36', 1, 1, '2026-09-13 22:09:36'),
(13, 30, '9221947013', 'scrypt:32768:8:1$e2o3PStj0PFTJbXz$aae08931b930cad75f313441caf86bd5d72b791c422dfabf232401e8cee9bf29001eb2ddad227adbbb451d81145885d187804962ed0ce630ea05a1c09e7b7fbf', '2026-09-13 22:21:52', 1, 1, '2026-09-13 22:16:52'),
(14, 8, '9789318024', 'scrypt:32768:8:1$vcSOYDmDM3iU36bs$04385c140d0722f15ae28a460cd8115aaa60f0643c6861cdca07d6cc0ae2c181052230004dc19756dde8161d4ee9f722513a2c7d636b80b142cff42461656f54', '2026-09-13 22:22:04', 1, 1, '2026-09-13 22:17:04'),
(15, 40, '9876543210', 'scrypt:32768:8:1$oiF3lvrYm7ReyMpP$754ea808109c754212145fedd4cd21ad8351b35abf2953160ce4f18263b20e50559065ec30c3fd719e4d0e5402b6d5383fa2792397a5c27281b6df7339471f08', '2026-09-20 20:04:06', 0, 0, '2026-09-20 19:59:06');

DROP TABLE IF EXISTS `driver_trips`;
CREATE TABLE `driver_trips` (
  `trip_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'Not Started',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`trip_id`)
) ENGINE=InnoDB AUTO_INCREMENT=50 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `driver_trips` (`trip_id`, `driver_id`, `bus_id`, `start_time`, `end_time`, `status`, `created_at`) VALUES
(1, 6, 3, '2026-08-31 20:58:17', '2026-08-31 20:58:23', 'Completed', '2026-08-31 20:58:17'),
(2, 6, 3, '2026-08-31 21:06:42', '2026-08-31 21:06:48', 'Completed', '2026-08-31 21:06:42'),
(3, 6, 3, '2026-08-31 21:07:27', '2026-08-31 21:07:42', 'Completed', '2026-08-31 21:07:27'),
(4, 6, 3, '2026-08-31 21:28:38', '2026-08-31 21:28:40', 'Completed', '2026-08-31 21:28:38'),
(5, 6, 3, '2026-08-31 21:28:48', '2026-08-31 21:28:55', 'Completed', '2026-08-31 21:28:48'),
(6, 6, 3, '2026-08-31 23:12:27', '2026-09-01 10:22:29', 'Completed', '2026-08-31 23:12:27'),
(7, 6, 3, '2026-09-01 10:23:53', '2026-09-01 10:23:57', 'Completed', '2026-09-01 10:23:53'),
(8, 8, 4, '2026-09-01 22:12:05', '2026-09-01 22:12:06', 'Completed', '2026-09-01 22:12:05'),
(9, 8, 4, '2026-09-01 22:23:26', '2026-09-01 22:23:26', 'Completed', '2026-09-01 22:23:26'),
(10, 8, 4, '2026-09-01 22:33:02', '2026-09-01 22:33:02', 'Completed', '2026-09-01 22:33:02'),
(11, 6, 3, '2026-09-02 09:37:24', '2026-09-02 09:37:41', 'Completed', '2026-09-02 09:37:24'),
(12, 8, 4, '2026-09-08 10:31:40', '2026-09-08 10:31:40', 'Completed', '2026-09-08 10:31:40'),
(13, 8, 4, '2026-09-08 10:39:26', '2026-09-08 10:39:26', 'Completed', '2026-09-08 10:39:26'),
(14, 8, 4, '2026-09-08 10:54:43', '2026-09-08 10:54:43', 'Completed', '2026-09-08 10:54:43'),
(15, 8, 4, '2026-09-08 10:55:10', '2026-09-08 10:55:10', 'Completed', '2026-09-08 10:55:10'),
(16, 8, 4, '2026-09-08 10:55:38', '2026-09-08 10:55:38', 'Completed', '2026-09-08 10:55:38'),
(17, 6, 3, '2026-09-09 09:32:50', NULL, 'Active', '2026-09-09 09:32:50'),
(18, 8, 4, '2026-09-13 21:10:47', '2026-09-13 21:10:47', 'Completed', '2026-09-13 21:10:47'),
(19, 8, 4, '2026-09-13 21:29:37', '2026-09-13 21:29:37', 'Completed', '2026-09-13 21:29:37'),
(20, 8, 4, '2026-09-13 22:09:36', '2026-09-13 22:09:36', 'Completed', '2026-09-13 22:09:36'),
(21, 8, 4, '2026-09-13 22:17:04', '2026-09-13 22:17:04', 'Completed', '2026-09-13 22:17:04'),
(22, 39, 3, '2026-09-14 21:29:16', '2026-09-14 21:29:16', 'Completed', '2026-09-14 21:29:16'),
(23, 40, 6, '2026-09-16 06:26:57', '2026-09-16 06:26:58', 'Completed', '2026-09-16 06:26:57'),
(24, 40, 6, '2026-09-16 06:31:13', '2026-09-16 06:36:50', 'Completed', '2026-09-16 06:31:13'),
(25, 40, 6, '2026-09-16 06:36:50', '2026-09-16 06:36:50', 'Completed', '2026-09-16 06:36:50'),
(26, 40, 6, '2026-09-16 06:48:24', '2026-09-16 09:06:31', 'Completed', '2026-09-16 06:48:24'),
(27, 40, 6, '2026-09-16 09:06:31', '2026-09-16 09:06:31', 'Completed', '2026-09-16 09:06:31'),
(28, 40, 6, '2026-09-16 09:08:24', '2026-09-16 09:08:35', 'Completed', '2026-09-16 09:08:24'),
(29, 40, 6, '2026-09-16 09:16:12', '2026-09-16 09:16:12', 'Completed', '2026-09-16 09:16:12'),
(30, 40, 6, '2026-09-16 09:18:44', '2026-09-16 09:24:43', 'Completed', '2026-09-16 09:18:44'),
(31, 40, 6, '2026-09-16 09:24:43', '2026-09-16 09:24:43', 'Completed', '2026-09-16 09:24:43'),
(32, 40, 6, '2026-09-16 10:43:33', '2026-09-16 10:43:33', 'Completed', '2026-09-16 10:43:33'),
(33, 40, 6, '2026-09-16 10:45:13', '2026-09-16 10:45:13', 'Completed', '2026-09-16 10:45:13'),
(34, 40, 6, '2026-09-16 10:55:23', '2026-09-16 10:57:56', 'Completed', '2026-09-16 10:55:23'),
(35, 40, 6, '2026-09-16 10:57:56', '2026-09-16 10:57:56', 'Completed', '2026-09-16 10:57:56'),
(36, 40, 6, '2026-09-20 19:18:32', '2026-09-20 19:18:33', 'Completed', '2026-09-20 19:18:32'),
(37, 40, 6, '2026-09-20 19:30:41', '2026-09-20 19:32:24', 'Completed', '2026-09-20 19:30:41'),
(38, 40, 6, '2026-09-20 19:55:28', '2026-09-20 19:55:28', 'Completed', '2026-09-20 19:55:28'),
(39, 47, 3, '2026-09-20 22:05:11', '2026-09-20 22:05:12', 'Completed', '2026-09-20 22:05:11'),
(40, 40, 6, '2026-09-21 20:13:38', '2026-09-21 20:45:33', 'Completed', '2026-09-21 20:13:38'),
(41, 49, 3, '2026-09-21 20:40:35', '2026-09-21 20:40:35', 'Completed', '2026-09-21 20:40:35'),
(42, 51, 3, '2026-09-21 21:21:48', '2026-09-21 21:21:48', 'Completed', '2026-09-21 21:21:48'),
(43, 53, 3, '2026-09-21 21:43:09', '2026-09-21 21:43:09', 'Completed', '2026-09-21 21:43:09'),
(44, 40, 6, '2026-09-21 21:47:09', '2026-09-21 21:47:12', 'Completed', '2026-09-21 21:47:09'),
(45, 55, 3, '2026-09-21 22:08:52', '2026-09-21 22:08:52', 'Completed', '2026-09-21 22:08:52'),
(46, 57, 3, '2026-09-21 22:34:43', '2026-09-21 22:34:43', 'Completed', '2026-09-21 22:34:43'),
(47, 59, 3, '2026-09-21 22:41:27', '2026-09-21 22:41:27', 'Completed', '2026-09-21 22:41:27'),
(48, 62, 3, '2026-09-21 23:11:08', '2026-09-21 23:11:08', 'Completed', '2026-09-21 23:11:08'),
(49, 40, 6, '2026-09-22 11:01:53', NULL, 'Active', '2026-09-22 11:01:53');

DROP TABLE IF EXISTS `parent_children`;
CREATE TABLE `parent_children` (
  `child_id` int(11) NOT NULL AUTO_INCREMENT,
  `parent_id` int(11) NOT NULL,
  `child_name` varchar(100) NOT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `route_id` int(11) DEFAULT NULL,
  `pickup_stop_id` int(11) DEFAULT NULL,
  `class_name` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`child_id`),
  KEY `parent_id` (`parent_id`),
  KEY `fk_child_bus` (`bus_id`),
  KEY `fk_child_route` (`route_id`),
  CONSTRAINT `fk_child_bus` FOREIGN KEY (`bus_id`) REFERENCES `buses` (`bus_id`),
  CONSTRAINT `fk_child_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`route_id`),
  CONSTRAINT `parent_children_ibfk_2` FOREIGN KEY (`bus_id`) REFERENCES `buses` (`bus_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `parent_children` (`child_id`, `parent_id`, `child_name`, `bus_id`, `route_id`, `pickup_stop_id`, `class_name`) VALUES
(4, 15, 'Anjali', 6, 1, 1, '8'),
(7, 20, 'E2E Child', 3, 1, 1, '7'),
(8, 21, 'E2E Child', 4, 1, 1, '7'),
(15, 48, 'Quality Student 1789922111509', 3, 1, 1, 'Class 5'),
(16, 50, 'Quality Student 1790003435331', 3, 1, 1, 'Class 5'),
(17, 52, 'Quality Student 1790005907501', 3, 1, 1, 'Class 5'),
(18, 54, 'Quality Student 1790007188730', 3, 1, 1, 'Class 5'),
(19, 56, 'Quality Student 1790008732375', 3, 1, 1, 'Class 5'),
(20, 58, 'Quality Student 1790010283303', 3, 1, 1, 'Class 5'),
(21, 60, 'Quality Student 1790010687447', 3, 1, 1, 'Class 5'),
(22, 63, 'Quality Student 1790012468019', 3, 1, 1, 'Class 5'),
(24, 65, 'Aneena', 8, 14, 30, '10th A');

DROP TABLE IF EXISTS `parent_registration_requests`;
CREATE TABLE `parent_registration_requests` (
  `request_id` int(11) NOT NULL AUTO_INCREMENT,
  `full_name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `child_name` varchar(100) NOT NULL,
  `child_class` varchar(50) DEFAULT NULL,
  `status` enum('PENDING','APPROVED','REJECTED') DEFAULT 'PENDING',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`request_id`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `parent_registration_requests` (`request_id`, `full_name`, `email`, `phone`, `password`, `child_name`, `child_class`, `status`, `created_at`) VALUES
(1, 'Anju', 'anju@gmail.com', '8768906543', 'scrypt:32768:8:1$RwpyDqOqEB34xFD4$befaf4c69f0f348fa02b0123f0eea70b8148664edfc7f76fba16186b4a6b38819551f0d3355afbf77f013607c84d7db328e7e90edfa51c1120e44181400e6271', 'Anjali', '8', 'APPROVED', '2026-09-01 19:57:45'),
(13, 'Gowri', 'gowri@gmail.com', '9087654326', 'scrypt:32768:8:1$rwPMseLlNeQ57kBB$84cdc289c772c199e7054b7fb9dd3b10eb709eb0cc36c1d544d9fd0f72db6143154374d3892461fe193b8829be243c80b1837f8fbb69b0539ecf9018dcd3f8c6', 'Ganga', '5', 'APPROVED', '2026-09-14 21:38:33'),
(14, 'Quality Parent 1789921973059', 'quality_parent_1789921973059@routesafe.com', '9123456780', 'scrypt:32768:8:1$QOGFdO2nkYXatQe4$692b3ad31cba4f3eeea35d764709015570968decf7adbb455b5fa3e0260f540344066a07e3aabe0734de301029fcc8544a764606912b6ace81a6e190423d4a42', 'Quality Student 1789921973059', '', 'PENDING', '2026-09-20 22:02:53'),
(15, 'Quality Parent 1789922111509', 'quality_parent_1789922111509@routesafe.com', '9123456780', 'scrypt:32768:8:1$BTNCml6jF9lqxy5H$5cbd464d227824a9497dd306e00e9235e888202344a1769a07ac09043c17dcdb2a7975897fb03e36eba54c7957261cb44bb45f87f348d9e06360130d6e0870fc', 'Quality Student 1789922111509', '', 'APPROVED', '2026-09-20 22:05:11'),
(16, 'Quality Parent 1790003435331', 'quality_parent_1790003435331@routesafe.com', '9123456780', 'scrypt:32768:8:1$2eXQGmAi4iu7Gvzk$38ccc8b6f98e3df1677e32abca3e47536cc173252dbc6a03cefe009ede0d3d24a9c76c18d3a9736d3ebeb558bdf43ee80e44cb81571f96c3e0f638d630b3eb80', 'Quality Student 1790003435331', '', 'APPROVED', '2026-09-21 20:40:35'),
(17, 'Quality Parent 1790005907501', 'quality_parent_1790005907501@routesafe.com', '9123456780', 'scrypt:32768:8:1$pfs7JporM6U3Xt1a$8e62abcc89131525b12fe351f1ef70030598e5ee641d55910e9190c32a0f39f831a0bba24a6e42c6631f8545dd32bdda25afdb487b7c1c0b006f74d74be53e5a', 'Quality Student 1790005907501', '', 'APPROVED', '2026-09-21 21:21:47'),
(18, 'Quality Parent 1790007188730', 'quality_parent_1790007188730@routesafe.com', '9123456780', 'scrypt:32768:8:1$DSLwuXSFhhJlWJu4$7e3c5479ac8917946a034ab45ed82e9c95996478c27b3cff7ba63116ae2d619eebfe311218e15c56627423f509bc7d710e92e9014244ce9359395aac52c7019c', 'Quality Student 1790007188730', '', 'APPROVED', '2026-09-21 21:43:09'),
(19, 'Quality Parent 1790008732375', 'quality_parent_1790008732375@routesafe.com', '9123456780', 'scrypt:32768:8:1$EpkU2ndhYpzPqFqA$a1be4f9be03d4810e9bee50e3a77586c7c1ad1c821a76b4501457f837f123cd89d5b2b1acb48daeb3b21675b94f888a92e83bfcfa3fd2f57b1f0e67b54f115d8', 'Quality Student 1790008732375', '', 'APPROVED', '2026-09-21 22:08:52'),
(20, 'Quality Parent 1790010283303', 'quality_parent_1790010283303@routesafe.com', '9123456780', 'scrypt:32768:8:1$kXmasEY9xqVCg5jn$9e514ebeb99f5aaef82b7879137f046b0b426fa3d0b181c3d94474d91ca120260ae93248692478ec0431cfeff6663f67678800d78dbf75d268088521ce0d0467', 'Quality Student 1790010283303', '', 'APPROVED', '2026-09-21 22:34:43'),
(21, 'Quality Parent 1790010687447', 'quality_parent_1790010687447@routesafe.com', '9123456780', 'scrypt:32768:8:1$uiWN07LcfdQd61C2$2f83ddade5ba851cd63765a81095a973b2f4c674111accdb382e85f5316d821caa68a374920bff144694e688fc67f28072ab0403c2f2dfdcbe16c05e8165b2c3', 'Quality Student 1790010687447', '', 'APPROVED', '2026-09-21 22:41:27'),
(22, 'Test Parent', 'testparent_1790012096545@gmail.com', '9876543210', 'scrypt:32768:8:1$MjHwjtZFEO11GR4W$d0a73b2fae1d7b9c3768a165e08b307617308c6b3708fa22af421e396e66f3af822400075b71ef32c812bcf53f4733c7708afaa5de1b27df6a836443f5f7db62', 'Test Child', 'Grade 5-A', 'PENDING', '2026-09-21 23:06:07'),
(23, 'Quality Parent 1790012468019', 'quality_parent_1790012468019@routesafe.com', '9123456780', 'scrypt:32768:8:1$1H5Y5GlSo1IVhOX7$64bb4fc3988dd07a294945f05966d0cb36b95108ddcb040563550d2d2dd59def375c627d8ce0374366521738dba7f2044fa46c1aa8be228e8e5fb816f9277d5b', 'Quality Student 1790012468019', '', 'APPROVED', '2026-09-21 23:11:08'),
(24, 'Gayathri', 'gayathri@gmail.com', '9072928621', 'scrypt:32768:8:1$WqgkwhJEPi8dro3y$a602673658f787dab7ce00120608d80f990bab6826defc31e781952b6aa1ad57c93418186550cab19d3a2aad46d50f3fa51663f071abea56c450f38a4dab4ca1', 'Rahul', '8 B', 'APPROVED', '2026-09-22 13:02:01');

DROP TABLE IF EXISTS `pickup_stops`;
CREATE TABLE `pickup_stops` (
  `stop_id` int(11) NOT NULL AUTO_INCREMENT,
  `route_id` int(11) NOT NULL,
  `stop_name` varchar(100) NOT NULL,
  `stop_order` int(11) DEFAULT 1,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  PRIMARY KEY (`stop_id`),
  KEY `route_id` (`route_id`),
  CONSTRAINT `pickup_stops_ibfk_1` FOREIGN KEY (`route_id`) REFERENCES `routes` (`route_id`)
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `pickup_stops` (`stop_id`, `route_id`, `stop_name`, `stop_order`, `latitude`, `longitude`) VALUES
(1, 1, 'Chengannur Town', 1, '9.3151000', '76.6151000'),
(2, 1, 'College Junction', 2, '9.3200000', '76.6200000'),
(3, 1, 'Market Stop', 3, '9.3250000', '76.6250000'),
(7, 2, 'Alappuzha Railway Station', 1, '9.4900000', '76.3260000'),
(8, 2, 'Alappuzha KSRTC', 2, '9.4981000', '76.3388000'),
(9, 2, 'Kommady', 3, '9.5050000', '76.3300000'),
(10, 3, 'Edathua Church', 1, '9.3640000', '76.4750000'),
(11, 3, 'Edathua Junction', 2, '9.3650000', '76.4755000'),
(12, 3, 'Thalavady', 3, '9.3730000', '76.5100000'),
(13, 4, 'Kadapra Junction', 1, '9.4000000', '76.5650000'),
(14, 4, 'Parumala', 2, '9.3850000', '76.5750000'),
(15, 4, 'Mannar', 3, '9.3230000', '76.5480000'),
(16, 5, 'Mavelikara Railway Station', 1, '9.2600000', '76.5560000'),
(17, 5, 'Mavelikara KSRTC', 2, '9.2605000', '76.5565000'),
(18, 5, 'Kandiyoor', 3, '9.2450000', '76.5600000'),
(19, 6, 'Thiruvalla Railway Station', 1, '9.3820000', '76.5740000'),
(20, 6, 'Thiruvalla KSRTC', 2, '9.3810000', '76.5745000'),
(21, 6, 'Ramanchira', 3, '9.3850000', '76.5750000'),
(22, 9, 'Pala Town', 1, '9.7050000', '76.6850000'),
(23, 9, 'Pala Bus Stand', 2, '9.7030000', '76.6855000'),
(24, 9, 'Meenachil', 3, '9.6900000', '76.7100000'),
(25, 14, 'Kottayam', 1, '9.5916000', '76.5222000'),
(26, 14, 'Nattakom', 2, '9.5556000', '76.5137000'),
(27, 14, 'Chingavanam', 3, '9.5248000', '76.5247000'),
(28, 14, 'Pathamuttom', 4, '9.5004000', '76.5519000'),
(29, 14, 'Saintgits College', 5, '9.5100000', '76.5514000'),
(30, 14, 'Saintgits College of Engineering', 6, '9.5092100', '76.5518300');

DROP TABLE IF EXISTS `routes`;
CREATE TABLE `routes` (
  `route_id` int(11) NOT NULL AUTO_INCREMENT,
  `route_name` varchar(100) NOT NULL,
  PRIMARY KEY (`route_id`),
  UNIQUE KEY `route_name` (`route_name`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `routes` (`route_id`, `route_name`) VALUES
(2, 'Alappuzha'),
(1, 'Chengannur'),
(3, 'Edathua'),
(8, 'Elanthoor'),
(4, 'Kadapra'),
(11, 'Kanjirapally'),
(10, 'Kayamkulam'),
(14, 'Kottayam'),
(13, 'Kumarakom'),
(7, 'Mallappally'),
(5, 'Mavelikara'),
(9, 'Pala'),
(12, 'Puramattom'),
(6, 'Thiruvalla');

DROP TABLE IF EXISTS `school_settings`;
CREATE TABLE `school_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `school_name` varchar(255) NOT NULL,
  `address` text NOT NULL,
  `latitude` double NOT NULL,
  `longitude` double NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `school_settings` (`id`, `school_name`, `address`, `latitude`, `longitude`, `updated_at`) VALUES
(1, 'Saintgits College of Applied Sciences', 'Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala - 686532', 9.50921, 76.55183, '2026-09-21 19:43:25');

DROP TABLE IF EXISTS `student_boarding`;
CREATE TABLE `student_boarding` (
  `attendance_id` int(11) NOT NULL AUTO_INCREMENT,
  `child_id` int(11) NOT NULL,
  `bus_id` int(11) NOT NULL,
  `driver_id` int(11) NOT NULL,
  `trip_id` int(11) DEFAULT NULL,
  `attendance_date` date NOT NULL,
  `boarding_status` enum('Not Boarded','Boarded','Dropped Off') DEFAULT 'Not Boarded',
  `boarding_time` time DEFAULT NULL,
  `drop_off_status` enum('Pending','Dropped Off') DEFAULT 'Pending',
  `drop_off_time` time DEFAULT NULL,
  `stop_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `unique_daily_child` (`child_id`,`attendance_date`,`bus_id`),
  KEY `bus_id` (`bus_id`),
  KEY `driver_id` (`driver_id`),
  CONSTRAINT `student_boarding_ibfk_1` FOREIGN KEY (`child_id`) REFERENCES `parent_children` (`child_id`) ON DELETE CASCADE,
  CONSTRAINT `student_boarding_ibfk_2` FOREIGN KEY (`bus_id`) REFERENCES `buses` (`bus_id`) ON DELETE CASCADE,
  CONSTRAINT `student_boarding_ibfk_3` FOREIGN KEY (`driver_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `student_boarding` (`attendance_id`, `child_id`, `bus_id`, `driver_id`, `trip_id`, `attendance_date`, `boarding_status`, `boarding_time`, `drop_off_status`, `drop_off_time`, `stop_id`, `created_at`) VALUES
(4, 4, 6, 40, 35, '2026-09-16', 'Boarded', '10:57:56', 'Pending', NULL, 1, '2026-09-16 10:57:56'),
(6, 4, 6, 40, 38, '2026-09-20', 'Boarded', '19:55:28', 'Pending', NULL, 1, '2026-09-20 19:55:28'),
(8, 8, 4, 8, NULL, '2026-09-20', 'Not Boarded', NULL, 'Pending', NULL, 1, '2026-09-20 21:30:22'),
(9, 15, 3, 47, NULL, '2026-09-20', 'Boarded', '22:05:11', 'Pending', NULL, 1, '2026-09-20 22:05:11'),
(10, 4, 6, 40, 40, '2026-09-21', 'Boarded', '20:20:26', 'Pending', NULL, 1, '2026-09-21 20:20:26'),
(11, 16, 3, 49, NULL, '2026-09-21', 'Boarded', '20:40:35', 'Pending', NULL, 1, '2026-09-21 20:40:35'),
(12, 17, 3, 51, NULL, '2026-09-21', 'Boarded', '21:21:48', 'Pending', NULL, 1, '2026-09-21 21:21:48'),
(13, 18, 3, 53, NULL, '2026-09-21', 'Boarded', '21:43:09', 'Pending', NULL, 1, '2026-09-21 21:43:09'),
(14, 19, 3, 55, NULL, '2026-09-21', 'Boarded', '22:08:52', 'Pending', NULL, 1, '2026-09-21 22:08:52'),
(15, 20, 3, 57, NULL, '2026-09-21', 'Boarded', '22:34:43', 'Pending', NULL, 1, '2026-09-21 22:34:43'),
(16, 21, 3, 59, NULL, '2026-09-21', 'Boarded', '22:41:27', 'Pending', NULL, 1, '2026-09-21 22:41:27'),
(17, 22, 3, 62, NULL, '2026-09-21', 'Boarded', '23:11:08', 'Pending', NULL, 1, '2026-09-21 23:11:08');

DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT,
  `full_name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `phone` varchar(15) DEFAULT NULL,
  `license_number` varchar(50) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `role` enum('Admin','Driver','Parent') NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` varchar(20) NOT NULL DEFAULT 'APPROVED',
  `rejection_reason` text DEFAULT NULL,
  `account_status` varchar(20) NOT NULL DEFAULT 'APPROVED',
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=67 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `users` (`user_id`, `full_name`, `email`, `phone`, `license_number`, `password`, `role`, `created_at`, `status`, `rejection_reason`, `account_status`) VALUES
(2, 'Anupama', 'anu@gmail.com', '9876543210', NULL, '123456', 'Parent', '2026-07-26 15:45:06', 'APPROVED', NULL, 'APPROVED'),
(4, 'Admin', 'admin@gmail.com', '7890766754', NULL, 'scrypt:32768:8:1$Iw2qTbtdoBGRiV0T$f3d8d89a74e9e4ef3c349e91170639dc4fcb7ad2ffdf2506e66a716df7171423ed63bad08c4eace3e152001a1fb5c9c3d966dda68f59f7d1f2954431d4f83673', 'Admin', '2026-07-26 22:08:51', 'APPROVED', NULL, 'APPROVED'),
(6, 'Ben', 'ben@gmail.com', '8765432134', NULL, 'scrypt:32768:8:1$sBOXazdP7syQ40W6$683205c914e6ab3652f31ad0bd87167e932450fc7f9ca936919fe604a807ec439da1a42b485ee70fedef2eced6d74cb6a0c60a81af85f1d8af1cbdd7b318c9b2', 'Driver', '2026-07-26 22:39:16', 'APPROVED', NULL, 'APPROVED'),
(7, 'Ann', 'ann@gmail.com', '6789543213', NULL, 'ann123', 'Parent', '2026-07-27 09:56:57', 'APPROVED', NULL, 'APPROVED'),
(8, 'Anil', 'anil@gmail.com', '9789318024', NULL, 'anil123', 'Driver', '2026-08-09 11:36:15', 'APPROVED', NULL, 'APPROVED'),
(15, 'Anju', 'anju@gmail.com', '8768906543', NULL, 'scrypt:32768:8:1$RwpyDqOqEB34xFD4$befaf4c69f0f348fa02b0123f0eea70b8148664edfc7f76fba16186b4a6b38819551f0d3355afbf77f013607c84d7db328e7e90edfa51c1120e44181400e6271', 'Parent', '2026-09-01 19:57:45', 'APPROVED', NULL, 'APPROVED'),
(17, 'Pending Parent Test', 'pendingtest@gmail.com', '9876543210', NULL, 'scrypt:32768:8:1$fvoDT1mwavNE4Lab$04346242f5ad3cf22fb6c96f897618cdd7cacd84d2df1d0a5c03499742324a319352f92f0df570cdccb15fbb8a763ded471edc1899824df580f1c21d72d22616', 'Parent', '2026-09-02 09:34:16', 'REJECTED', NULL, 'APPROVED'),
(18, 'Pending Fix Test', 'test_pr_fix@gmail.com', '9988776655', NULL, 'scrypt:32768:8:1$HR9x6QZ2GuMonRWX$22a068d33399ca3e513061202800a6fb0f321d684560bce12be9e7f2f9716ff7032c2b56930a25901c4a4884bc948c597dd8769f20b99d71c255c2d7d7111d65', 'Parent', '2026-09-02 09:42:25', 'REJECTED', NULL, 'APPROVED'),
(25, 'Anoop', 'anoop@gmail.com', '9087567890', NULL, 'scrypt:32768:8:1$waOlxep9HhBONwfa$9830397ada637cb4a3749decb9e1120c90fd6c31aba2bc37f1a5e0b9d4af44679daa7daed53d8e8faa6851101dfaa3321a2033f66de9a41917adaed89830a3e7', 'Driver', '2026-09-13 21:32:15', 'APPROVED', NULL, 'APPROVED'),
(28, 'Test Driver 317562', 'test_driver_317562@gmail.com', '9609364896', NULL, 'scrypt:32768:8:1$s1Mtzocf8u3Lce8B$b8e31acd568cb25d434b868e8759238bf0304f2d748d797802d2edc6ee9ddb7d82bee5b184673b4bf7edcd037aa732e48b87db504f2e2d687777809b72cab9ad', 'Driver', '2026-09-13 22:09:22', 'APPROVED', NULL, 'APPROVED'),
(30, 'Test Driver 318011', 'test_driver_318011@gmail.com', '9221947013', NULL, 'scrypt:32768:8:1$DsDpk0BFXiblLpLV$620138c4c0ca4733354c43825d7d82c703bada91a7333f36aebdd5516378ae9eb374ff5e7be77141c10335b23a3810a3a5201ffc1a0c45a7b30dc55c9c9a7e57', 'Driver', '2026-09-13 22:16:52', 'APPROVED', NULL, 'APPROVED'),
(34, 'Test Driver Unit', 'drivertest_1789401113548890700@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$o3XW3A9bX3ZOYM8W$29e35d2190972d9c7adfe3fa1d9fc25d5430d16bc9e810d2c127a7d66561777c9c817edc8ffd2cc25790f304389da9b2efcf1191c76834f688a438732f71cca1', 'Driver', '2026-09-14 21:21:53', 'REJECTED', NULL, 'APPROVED'),
(40, 'Benit', 'benit@gmail.com', '8590528843', NULL, 'scrypt:32768:8:1$m048mYSLrcSFB4ef$f86460d0d3e95b6a087fca28a44c0fd27e0a1cb2809eb847c4741b44ee448bed901da27369a2778f9198aab161cc6710d102a701e4ec5ec811b9118abfefdd65', 'Driver', '2026-09-14 21:37:19', 'APPROVED', NULL, 'APPROVED'),
(41, 'Gowri', 'gowri@gmail.com', '9087654326', NULL, 'scrypt:32768:8:1$rwPMseLlNeQ57kBB$84cdc289c772c199e7054b7fb9dd3b10eb709eb0cc36c1d544d9fd0f72db6143154374d3892461fe193b8829be243c80b1837f8fbb69b0539ecf9018dcd3f8c6', 'Parent', '2026-09-14 21:38:33', 'APPROVED', NULL, 'APPROVED'),
(44, 'Quality Driver 1789921914890', 'quality_driver_1789921914890@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$7I0Xvg8LTN3TZU9X$c24adf8ce404c2b78243aba8cd3d69acc067d4076e5dfb01c71af42bf293bb4ccf6b1f5a1a87947afd8ef0cc6b27830a9e21ad5bca198f309f465197d38ce5b4', 'Driver', '2026-09-20 22:01:55', 'APPROVED', NULL, 'APPROVED'),
(45, 'Quality Driver 1789921973059', 'quality_driver_1789921973059@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$tNxciZzKrLIHaGg5$40d0d3c2584317434b7f3e0f45a8b444a7014385a791dc61f94cde7dd705698fd566eee383978d4e7156f2da173659c71904a17a657e368a01ca8305567a55da', 'Driver', '2026-09-20 22:02:53', 'APPROVED', NULL, 'APPROVED'),
(46, 'Quality Parent 1789921973059', 'quality_parent_1789921973059@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$QOGFdO2nkYXatQe4$692b3ad31cba4f3eeea35d764709015570968decf7adbb455b5fa3e0260f540344066a07e3aabe0734de301029fcc8544a764606912b6ace81a6e190423d4a42', 'Parent', '2026-09-20 22:02:53', 'PENDING', NULL, 'APPROVED'),
(47, 'Quality Driver 1789922111509', 'quality_driver_1789922111509@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$gvRRTMFKSjiGnHw0$49bfd033099760715e544fdf6c109b114f990293e47e8de7d1f9c69a44b1f2040c883e11d7e809f79bc339877ffd081ef96dc0dc7a7f541292de24e77fd73592', 'Driver', '2026-09-20 22:05:11', 'APPROVED', NULL, 'APPROVED'),
(48, 'Quality Parent 1789922111509', 'quality_parent_1789922111509@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$BTNCml6jF9lqxy5H$5cbd464d227824a9497dd306e00e9235e888202344a1769a07ac09043c17dcdb2a7975897fb03e36eba54c7957261cb44bb45f87f348d9e06360130d6e0870fc', 'Parent', '2026-09-20 22:05:11', 'APPROVED', NULL, 'APPROVED'),
(49, 'Quality Driver 1790003435331', 'quality_driver_1790003435331@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$dxflhGCsYrWiltUX$d9f53f97dcd8391b839bbae1c930d3f3ea5ebc82aab4cd7ecd581241abd23787ec6f1a973f5976a55d74453fb9c9b27bf6bf6da38c418ebbb827d23065f1a024', 'Driver', '2026-09-21 20:40:35', 'APPROVED', NULL, 'APPROVED'),
(50, 'Quality Parent 1790003435331', 'quality_parent_1790003435331@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$2eXQGmAi4iu7Gvzk$38ccc8b6f98e3df1677e32abca3e47536cc173252dbc6a03cefe009ede0d3d24a9c76c18d3a9736d3ebeb558bdf43ee80e44cb81571f96c3e0f638d630b3eb80', 'Parent', '2026-09-21 20:40:35', 'APPROVED', NULL, 'APPROVED'),
(51, 'Quality Driver 1790005907501', 'quality_driver_1790005907501@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$PCyM9cXTKrdjk5Xk$ccd229bf1022f22884d4cfe0001abb8f033a2e66f02bc07b771befd57c1274f0aa6c0a305b1c855c23eccee54639f895d0f68c3bd0ed4a706730d68bb962aebb', 'Driver', '2026-09-21 21:21:47', 'APPROVED', NULL, 'APPROVED'),
(52, 'Quality Parent 1790005907501', 'quality_parent_1790005907501@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$pfs7JporM6U3Xt1a$8e62abcc89131525b12fe351f1ef70030598e5ee641d55910e9190c32a0f39f831a0bba24a6e42c6631f8545dd32bdda25afdb487b7c1c0b006f74d74be53e5a', 'Parent', '2026-09-21 21:21:47', 'APPROVED', NULL, 'APPROVED'),
(53, 'Quality Driver 1790007188730', 'quality_driver_1790007188730@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$4qIljtJpMQp93XyI$2a92f9b70d806b766d06e575cfdb4f3164a2f59bfa807a701cadee41031931d0b1477ef50a6ab579c6fe58d396d1a324fcd4d007a4b37fb826d9d29f3759cd5c', 'Driver', '2026-09-21 21:43:08', 'APPROVED', NULL, 'APPROVED'),
(54, 'Quality Parent 1790007188730', 'quality_parent_1790007188730@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$DSLwuXSFhhJlWJu4$7e3c5479ac8917946a034ab45ed82e9c95996478c27b3cff7ba63116ae2d619eebfe311218e15c56627423f509bc7d710e92e9014244ce9359395aac52c7019c', 'Parent', '2026-09-21 21:43:09', 'APPROVED', NULL, 'APPROVED'),
(55, 'Quality Driver 1790008732375', 'quality_driver_1790008732375@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$UPMcaJZMKbAkcV5Z$3afa8ee378cb3745bcd8db446dcc2a3f24eb04097d44a78dfc3a73cc9f91861b6af9fcce456ce335141c8b31d61dfd0fe3617d2e3e16566bb4be7c4f6d1ceb65', 'Driver', '2026-09-21 22:08:52', 'APPROVED', NULL, 'APPROVED'),
(56, 'Quality Parent 1790008732375', 'quality_parent_1790008732375@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$EpkU2ndhYpzPqFqA$a1be4f9be03d4810e9bee50e3a77586c7c1ad1c821a76b4501457f837f123cd89d5b2b1acb48daeb3b21675b94f888a92e83bfcfa3fd2f57b1f0e67b54f115d8', 'Parent', '2026-09-21 22:08:52', 'APPROVED', NULL, 'APPROVED'),
(57, 'Quality Driver 1790010283303', 'quality_driver_1790010283303@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$CEQoYsDmeclZQI0v$f747966db4f6dc0d44091f8a1e216408e0e75d3803d3e9da2762f71278f31f2d7f12f00db61680806eb0d1f6db3c76ed372e4db384286d16fae9e998cf950d13', 'Driver', '2026-09-21 22:34:43', 'APPROVED', NULL, 'APPROVED'),
(58, 'Quality Parent 1790010283303', 'quality_parent_1790010283303@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$kXmasEY9xqVCg5jn$9e514ebeb99f5aaef82b7879137f046b0b426fa3d0b181c3d94474d91ca120260ae93248692478ec0431cfeff6663f67678800d78dbf75d268088521ce0d0467', 'Parent', '2026-09-21 22:34:43', 'APPROVED', NULL, 'APPROVED'),
(59, 'Quality Driver 1790010687447', 'quality_driver_1790010687447@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$SMbIdNyKCXKR3No6$991d560b31151bcc05c5e279b4deb9df31dc31b2f13f2a34eea4a5dd0c566d5b3568a886866c9267f4c9768bcc50a335098ea29f144a1376776faa6da354d1da', 'Driver', '2026-09-21 22:41:27', 'APPROVED', NULL, 'APPROVED'),
(60, 'Quality Parent 1790010687447', 'quality_parent_1790010687447@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$uiWN07LcfdQd61C2$2f83ddade5ba851cd63765a81095a973b2f4c674111accdb382e85f5316d821caa68a374920bff144694e688fc67f28072ab0403c2f2dfdcbe16c05e8165b2c3', 'Parent', '2026-09-21 22:41:27', 'APPROVED', NULL, 'APPROVED'),
(61, 'Test Parent', 'testparent_1790012096545@gmail.com', '9876543210', NULL, 'scrypt:32768:8:1$MjHwjtZFEO11GR4W$d0a73b2fae1d7b9c3768a165e08b307617308c6b3708fa22af421e396e66f3af822400075b71ef32c812bcf53f4733c7708afaa5de1b27df6a836443f5f7db62', 'Parent', '2026-09-21 23:06:07', 'PENDING', NULL, 'APPROVED'),
(62, 'Quality Driver 1790012468019', 'quality_driver_1790012468019@routesafe.com', '9876543210', NULL, 'scrypt:32768:8:1$90YKFpKv4ndqPZFl$c9790a57262bee9de50d8ab486839fc0f62b84a783a6dd8071e8ec510d209cd3e023e46c94c53ba092e29b55d48ab119b9dfee5575915e97b0e0bf81ed9b41d4', 'Driver', '2026-09-21 23:11:08', 'APPROVED', NULL, 'APPROVED'),
(63, 'Quality Parent 1790012468019', 'quality_parent_1790012468019@routesafe.com', '9123456780', NULL, 'scrypt:32768:8:1$1H5Y5GlSo1IVhOX7$64bb4fc3988dd07a294945f05966d0cb36b95108ddcb040563550d2d2dd59def375c627d8ce0374366521738dba7f2044fa46c1aa8be228e8e5fb816f9277d5b', 'Parent', '2026-09-21 23:11:08', 'APPROVED', NULL, 'APPROVED'),
(64, 'Gayathri', 'gayathri@gmail.com', '9072928621', NULL, 'scrypt:32768:8:1$WqgkwhJEPi8dro3y$a602673658f787dab7ce00120608d80f990bab6826defc31e781952b6aa1ad57c93418186550cab19d3a2aad46d50f3fa51663f071abea56c450f38a4dab4ca1', 'Parent', '2026-09-22 13:02:01', 'APPROVED', NULL, 'APPROVED'),
(65, 'Cincy', 'cincy@gmail.com', '9847123456', NULL, 'scrypt:32768:8:1$fnjRDJPWP3RQigrb$5ec1d9ef09e08b11f955023230c40cad35c16fd243bf8deece352fb0417b923d3bb4c33a8cfd8a58ca2c9044f6c78f769a11615764cff772466a9accbd653403', 'Parent', '2026-09-22 14:44:33', 'APPROVED', NULL, 'APPROVED'),
(66, 'Soman', 'soman@gmail.com', '9072928621', NULL, 'scrypt:32768:8:1$JNZCG3BWWGlP1PHf$c7f57360f83748892956b7d7aad262ce40533d6256adefaf3e6ebd55679dd6c63396226c95b8928019c39d25b0a92ecbdc8438f095440e9eaf62a1ee13d725e1', 'Driver', '2026-09-22 14:44:33', 'APPROVED', NULL, 'APPROVED');

SET FOREIGN_KEY_CHECKS = 1;
