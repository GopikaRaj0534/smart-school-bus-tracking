SET FOREIGN_KEY_CHECKS = 0;

-- 1. users
CREATE TABLE IF NOT EXISTS `users` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `users` (`user_id`, `full_name`, `email`, `phone`, `license_number`, `password`, `role`, `created_at`, `status`, `rejection_reason`, `account_status`) VALUES
(2, 'Anupama', 'anu@gmail.com', '9876543210', NULL, '123456', 'Parent', '2026-07-26 15:45:06', 'APPROVED', NULL, 'APPROVED'),
(4, 'Admin', 'admin@gmail.com', '7890766754', NULL, 'scrypt:32768:8:1$Iw2qTbtdoBGRiV0T$f3d8d89a74e9e4ef3c349e91170639dc4fcb7ad2ffdf2506e66a716df7171423ed63bad08c4eace3e152001a1fb5c9c3d966dda68f59f7d1f2954431d4f83673', 'Admin', '2026-07-26 22:08:51', 'APPROVED', NULL, 'APPROVED'),
(6, 'Ben', 'ben@gmail.com', '8765432134', NULL, 'scrypt:32768:8:1$sBOXazdP7syQ40W6$683205c914e6ab3652f31ad0bd87167e932450fc7f9ca936919fe604a807ec439da1a42b485ee70fedef2eced6d74cb6a0c60a81af85f1d8af1cbdd7b318c9b2', 'Driver', '2026-07-26 22:39:16', 'APPROVED', NULL, 'APPROVED'),
(7, 'Ann', 'ann@gmail.com', '6789543213', NULL, 'ann123', 'Parent', '2026-07-27 09:56:57', 'APPROVED', NULL, 'APPROVED'),
(8, 'Anil', 'anil@gmail.com', '9789318024', NULL, 'anil123', 'Driver', '2026-08-09 11:36:15', 'APPROVED', NULL, 'APPROVED'),
(15, 'Anju', 'anju@gmail.com', '8768906543', NULL, 'scrypt:32768:8:1$RwpyDqOqEB34xFD4$befaf4c69f0f348fa02b0123f0eea70b8148664edfc7f76fba16186b4a6b38819551f0d3355afbf77f013607c84d7db328e7e90edfa51c1120e44181400e6271', 'Parent', '2026-09-01 19:57:45', 'APPROVED', NULL, 'APPROVED'),
(25, 'Anoop', 'anoop@gmail.com', '9087567890', NULL, 'scrypt:32768:8:1$waOlxep9HhBONwfa$9830397ada637cb4a3749decb9e1120c90fd6c31aba2bc37f1a5e0b9d4af44679daa7daed53d8e8faa6851101dfaa3321a2033f66de9a41917adaed89830a3e7', 'Driver', '2026-09-13 21:32:15', 'APPROVED', NULL, 'APPROVED'),
(40, 'Benit', 'benit@gmail.com', '8590528843', NULL, 'scrypt:32768:8:1$m048mYSLrcSFB4ef$f86460d0d3e95b6a087fca28a44c0fd27e0a1cb2809eb847c4741b44ee448bed901da27369a2778f9198aab161cc6710d102a701e4ec5ec811b9118abfefdd65', 'Driver', '2026-09-14 21:37:19', 'APPROVED', NULL, 'APPROVED'),
(41, 'Gowri', 'gowri@gmail.com', '9087654326', NULL, 'scrypt:32768:8:1$rwPMseLlNeQ57kBB$84cdc289c772c199e7054b7fb9dd3b10eb709eb0cc36c1d544d9fd0f72db6143154374d3892461fe193b8829be243c80b1837f8fbb69b0539ecf9018dcd3f8c6', 'Parent', '2026-09-14 21:38:33', 'APPROVED', NULL, 'APPROVED'),
(64, 'Gayathri', 'gayathri@gmail.com', '9072928621', NULL, 'scrypt:32768:8:1$WqgkwhJEPi8dro3y$a602673658f787dab7ce00120608d80f990bab6826defc31e781952b6aa1ad57c93418186550cab19d3a2aad46d50f3fa51663f071abea56c450f38a4dab4ca1', 'Parent', '2026-09-22 13:02:01', 'APPROVED', NULL, 'APPROVED'),
(65, 'Cincy', 'cincy@gmail.com', '9847123456', NULL, 'scrypt:32768:8:1$fnjRDJPWP3RQigrb$5ec1d9ef09e08b11f955023230c40cad35c16fd243bf8deece352fb0417b923d3bb4c33a8cfd8a58ca2c9044f6c78f769a11615764cff772466a9accbd653403', 'Parent', '2026-09-22 14:44:33', 'APPROVED', NULL, 'APPROVED'),
(66, 'Soman', 'soman@gmail.com', '9072928621', NULL, 'scrypt:32768:8:1$JNZCG3BWWGlP1PHf$c7f57360f83748892956b7d7aad262ce40533d6256adefaf3e6ebd55679dd6c63396226c95b8928019c39d25b0a92ecbdc8438f095440e9eaf62a1ee13d725e1', 'Driver', '2026-09-22 14:44:33', 'APPROVED', NULL, 'APPROVED');

-- 2. routes
CREATE TABLE IF NOT EXISTS `routes` (
  `route_id` int(11) NOT NULL AUTO_INCREMENT,
  `route_name` varchar(100) NOT NULL,
  PRIMARY KEY (`route_id`),
  UNIQUE KEY `route_name` (`route_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `routes` (`route_id`, `route_name`) VALUES
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

-- 3. pickup_stops
CREATE TABLE IF NOT EXISTS `pickup_stops` (
  `stop_id` int(11) NOT NULL AUTO_INCREMENT,
  `route_id` int(11) NOT NULL,
  `stop_name` varchar(100) NOT NULL,
  `stop_order` int(11) DEFAULT 1,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  PRIMARY KEY (`stop_id`),
  KEY `route_id` (`route_id`),
  CONSTRAINT `pickup_stops_ibfk_1` FOREIGN KEY (`route_id`) REFERENCES `routes` (`route_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `pickup_stops` (`stop_id`, `route_id`, `stop_name`, `stop_order`, `latitude`, `longitude`) VALUES
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

-- 4. buses
CREATE TABLE IF NOT EXISTS `buses` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `buses` (`bus_id`, `bus_number`, `registration_number`, `route`, `driver_name`, `status`, `start_point`, `destination`, `driver_id`, `created_at`) VALUES
(3, '11', NULL, 'Chengannur', 'Quality Driver', 'Active', NULL, NULL, 62, '2026-07-26 22:27:08'),
(4, '12', NULL, 'Pala', 'Anil', 'Active', NULL, NULL, 8, '2026-08-09 15:52:39'),
(6, '1', NULL, 'Thiruvalla', 'Benit', 'Active', NULL, NULL, 40, '2026-09-13 21:31:07'),
(7, '10', NULL, 'Chengannur', 'Ben', 'Active', NULL, NULL, 6, '2026-09-20 20:27:38'),
(8, '14', 'KL-05-AB-1414', 'Kottayam', 'Soman', 'Active', NULL, NULL, 66, '2026-09-22 14:46:49');

-- 5. parent_children
CREATE TABLE IF NOT EXISTS `parent_children` (
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
  CONSTRAINT `fk_child_bus` FOREIGN KEY (`bus_id`) REFERENCES `buses` (`bus_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_child_route` FOREIGN KEY (`route_id`) REFERENCES `routes` (`route_id`) ON DELETE SET NULL,
  CONSTRAINT `parent_children_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `parent_children` (`child_id`, `parent_id`, `child_name`, `bus_id`, `route_id`, `pickup_stop_id`, `class_name`) VALUES
(4, 15, 'Anjali', 6, 1, 1, '8'),
(24, 65, 'Aneena', 8, 14, 30, '10th A');

-- 6. student_boarding
CREATE TABLE IF NOT EXISTS `student_boarding` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 7. driver_trips
CREATE TABLE IF NOT EXISTS `driver_trips` (
  `trip_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `bus_id` int(11) DEFAULT NULL,
  `start_time` datetime DEFAULT NULL,
  `end_time` datetime DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'Not Started',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`trip_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 8. driver_locations
CREATE TABLE IF NOT EXISTS `driver_locations` (
  `location_id` int(11) NOT NULL AUTO_INCREMENT,
  `driver_id` int(11) NOT NULL,
  `latitude` decimal(10,7) NOT NULL,
  `longitude` decimal(10,7) NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`location_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 9. driver_emergencies
CREATE TABLE IF NOT EXISTS `driver_emergencies` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 10. parent_registration_requests
CREATE TABLE IF NOT EXISTS `parent_registration_requests` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 11. driver_phone_otp
CREATE TABLE IF NOT EXISTS `driver_phone_otp` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 12. assignment_logs
CREATE TABLE IF NOT EXISTS `assignment_logs` (
  `log_id` int(11) NOT NULL AUTO_INCREMENT,
  `entity_type` varchar(50) NOT NULL,
  `entity_id` int(11) DEFAULT NULL,
  `action` varchar(50) NOT NULL,
  `details` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`log_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 13. child_bus_absence
CREATE TABLE IF NOT EXISTS `child_bus_absence` (
  `absence_id` int(11) NOT NULL AUTO_INCREMENT,
  `child_id` int(11) NOT NULL,
  `parent_id` int(11) NOT NULL,
  `route_id` int(11) DEFAULT NULL,
  `stop_id` int(11) DEFAULT NULL,
  `absence_date` date NOT NULL,
  `status` varchar(50) NOT NULL DEFAULT 'Not Riding Today',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`absence_id`),
  UNIQUE KEY `unique_child_daily_absence` (`child_id`,`absence_date`),
  KEY `fk_absence_child` (`child_id`),
  KEY `fk_absence_parent` (`parent_id`),
  CONSTRAINT `fk_absence_child` FOREIGN KEY (`child_id`) REFERENCES `parent_children` (`child_id`) ON DELETE CASCADE,
  CONSTRAINT `fk_absence_parent` FOREIGN KEY (`parent_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 14. school_settings
CREATE TABLE IF NOT EXISTS `school_settings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `school_name` varchar(255) NOT NULL,
  `address` text NOT NULL,
  `latitude` double NOT NULL,
  `longitude` double NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Default School Settings
INSERT IGNORE INTO `school_settings` (`id`, `school_name`, `address`, `latitude`, `longitude`, `updated_at`) VALUES
(1, 'Saintgits College of Applied Sciences', 'Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala - 686532', 9.50921, 76.55183, CURRENT_TIMESTAMP);

SET FOREIGN_KEY_CHECKS = 1;
