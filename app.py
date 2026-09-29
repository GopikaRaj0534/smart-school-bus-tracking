from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import os
import re
import random
import hashlib
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


# ============================================================
# APP CONFIGURATION
# ============================================================

app = Flask(__name__)
CORS(app)


# ============================================================
# ============================================================
# DATABASE CONFIGURATION
# ============================================================

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", os.environ.get("MYSQL_HOST", "localhost")),
    "port": int(os.environ.get("DB_PORT", os.environ.get("MYSQL_PORT", "3306"))),
    "user": os.environ.get("DB_USER", os.environ.get("MYSQL_USER", "root")),
    "password": os.environ.get("DB_PASSWORD", os.environ.get("MYSQL_PASSWORD", "")),
    "database": os.environ.get("DB_NAME", os.environ.get("MYSQL_DATABASE", "defaultdb"))
}

# Support optional SSL CA certificate / SSL configuration if required by cloud provider (e.g. Aiven)
ssl_disabled = os.environ.get("DB_SSL_DISABLED", "").lower() in ("true", "1", "yes")
if not ssl_disabled:
    ssl_ca = os.environ.get("DB_SSL_CA")
    if ssl_ca:
        DB_CONFIG["ssl_ca"] = ssl_ca


# ============================================================
# DATABASE CONNECTION & AUTOMATIC TABLE INITIALIZATION
# ============================================================

def get_db():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except mysql.connector.Error as e:
        if DB_CONFIG.get("host") in ("localhost", "127.0.0.1"):
            try:
                local_config = {
                    "host": "localhost",
                    "port": 3306,
                    "user": "root",
                    "password": "",
                    "database": os.environ.get("DB_NAME", os.environ.get("MYSQL_DATABASE", "defaultdb"))
                }
                return mysql.connector.connect(**local_config)
            except mysql.connector.Error:
                pass
        raise e


_tables_ensured = False

def ensure_all_tables():
    global _tables_ensured
    if _tables_ensured:
        return
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor()

        # 1. users
        cursor.execute("""
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
        """)

        cursor.execute("""
            INSERT IGNORE INTO `users` (`user_id`, `full_name`, `email`, `phone`, `license_number`, `password`, `role`, `created_at`, `status`, `rejection_reason`, `account_status`) VALUES
            (2, 'Anupama', 'anu@gmail.com', '9876543210', NULL, '123456', 'Parent', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (4, 'Admin', 'admin@gmail.com', '7890766754', NULL, 'scrypt:32768:8:1$Iw2qTbtdoBGRiV0T$f3d8d89a74e9e4ef3c349e91170639dc4fcb7ad2ffdf2506e66a716df7171423ed63bad08c4eace3e152001a1fb5c9c3d966dda68f59f7d1f2954431d4f83673', 'Admin', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (6, 'Ben', 'ben@gmail.com', '8765432134', NULL, 'scrypt:32768:8:1$sBOXazdP7syQ40W6$683205c914e6ab3652f31ad0bd87167e932450fc7f9ca936919fe604a807ec439da1a42b485ee70fedef2eced6d74cb6a0c60a81af85f1d8af1cbdd7b318c9b2', 'Driver', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (7, 'Ann', 'ann@gmail.com', '6789543213', NULL, 'ann123', 'Parent', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (8, 'Anil', 'anil@gmail.com', '9789318024', NULL, 'anil123', 'Driver', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (15, 'Anju', 'anju@gmail.com', '8768906543', NULL, 'scrypt:32768:8:1$RwpyDqOqEB34xFD4$befaf4c69f0f348fa02b0123f0eea70b8148664edfc7f76fba16186b4a6b38819551f0d3355afbf77f013607c84d7db328e7e90edfa51c1120e44181400e6271', 'Parent', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (25, 'Anoop', 'anoop@gmail.com', '9087567890', NULL, 'scrypt:32768:8:1$waOlxep9HhBONwfa$9830397ada637cb4a3749decb9e1120c90fd6c31aba2bc37f1a5e0b9d4af44679daa7daed53d8e8faa6851101dfaa3321a2033f66de9a41917adaed89830a3e7', 'Driver', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (40, 'Benit', 'benit@gmail.com', '8590528843', NULL, 'scrypt:32768:8:1$m048mYSLrcSFB4ef$f86460d0d3e95b6a087fca28a44c0fd27e0a1cb2809eb847c4741b44ee448bed901da27369a2778f9198aab161cc6710d102a701e4ec5ec811b9118abfefdd65', 'Driver', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (41, 'Gowri', 'gowri@gmail.com', '9087654326', NULL, 'scrypt:32768:8:1$rwPMseLlNeQ57kBB$84cdc289c772c199e7054b7fb9dd3b10eb709eb0cc36c1d544d9fd0f72db6143154374d3892461fe193b8829be243c80b1837f8fbb69b0539ecf9018dcd3f8c6', 'Parent', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (64, 'Gayathri', 'gayathri@gmail.com', '9072928621', NULL, 'scrypt:32768:8:1$WqgkwhJEPi8dro3y$a602673658f787dab7ce00120608d80f990bab6826defc31e781952b6aa1ad57c93418186550cab19d3a2aad46d50f3fa51663f071abea56c450f38a4dab4ca1', 'Parent', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (65, 'Cincy', 'cincy@gmail.com', '9847123456', NULL, 'scrypt:32768:8:1$fnjRDJPWP3RQigrb$5ec1d9ef09e08b11f955023230c40cad35c16fd243bf8deece352fb0417b923d3bb4c33a8cfd8a58ca2c9044f6c78f769a11615764cff772466a9accbd653403', 'Parent', NOW(), 'APPROVED', NULL, 'APPROVED'),
            (66, 'Soman', 'soman@gmail.com', '9072928621', NULL, 'scrypt:32768:8:1$JNZCG3BWWGlP1PHf$c7f57360f83748892956b7d7aad262ce40533d6256adefaf3e6ebd55679dd6c63396226c95b8928019c39d25b0a92ecbdc8438f095440e9eaf62a1ee13d725e1', 'Driver', NOW(), 'APPROVED', NULL, 'APPROVED');
        """)

        # 2. routes
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS `routes` (
              `route_id` int(11) NOT NULL AUTO_INCREMENT,
              `route_name` varchar(100) NOT NULL,
              PRIMARY KEY (`route_id`),
              UNIQUE KEY `route_name` (`route_name`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """)

        cursor.execute("""
            INSERT IGNORE INTO `routes` (`route_id`, `route_name`) VALUES
            (2, 'Alappuzha'), (1, 'Chengannur'), (3, 'Edathua'), (8, 'Elanthoor'), (4, 'Kadapra'), (11, 'Kanjirapally'),
            (10, 'Kayamkulam'), (14, 'Kottayam'), (13, 'Kumarakom'), (7, 'Mallappally'), (5, 'Mavelikara'), (9, 'Pala'), (12, 'Puramattom'), (6, 'Thiruvalla');
        """)

        # 3. pickup_stops
        cursor.execute("""
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
        """)

        cursor.execute("""
            INSERT IGNORE INTO `pickup_stops` (`stop_id`, `route_id`, `stop_name`, `stop_order`, `latitude`, `longitude`) VALUES
            (1, 1, 'Chengannur Town', 1, 9.3151000, 76.6151000),
            (2, 1, 'College Junction', 2, 9.3200000, 76.6200000),
            (3, 1, 'Market Stop', 3, 9.3250000, 76.6250000),
            (7, 2, 'Alappuzha Railway Station', 1, 9.4900000, 76.3260000),
            (8, 2, 'Alappuzha KSRTC', 2, 9.4981000, 76.3388000),
            (9, 2, 'Kommady', 3, 9.5050000, 76.3300000),
            (10, 3, 'Edathua Church', 1, 9.3640000, 76.4750000),
            (11, 3, 'Edathua Junction', 2, 9.3650000, 76.4755000),
            (12, 3, 'Thalavady', 3, 9.3730000, 76.5100000),
            (13, 4, 'Kadapra Junction', 1, 9.4000000, 76.5650000),
            (14, 4, 'Parumala', 2, 9.3850000, 76.5750000),
            (15, 4, 'Mannar', 3, 9.3230000, 76.5480000),
            (16, 5, 'Mavelikara Railway Station', 1, 9.2600000, 76.5560000),
            (17, 5, 'Mavelikara KSRTC', 2, 9.2605000, 76.5565000),
            (18, 5, 'Kandiyoor', 3, 9.2450000, 76.5600000),
            (19, 6, 'Thiruvalla Railway Station', 1, 9.3820000, 76.5740000),
            (20, 6, 'Thiruvalla KSRTC', 2, 9.3810000, 76.5745000),
            (21, 6, 'Ramanchira', 3, 9.3850000, 76.5750000),
            (22, 9, 'Pala Town', 1, 9.7050000, 76.6850000),
            (23, 9, 'Pala Bus Stand', 2, 9.7030000, 76.6855000),
            (24, 9, 'Meenachil', 3, 9.6900000, 76.7100000),
            (25, 14, 'Kottayam', 1, 9.5916000, 76.5222000),
            (26, 14, 'Nattakom', 2, 9.5556000, 76.5137000),
            (27, 14, 'Chingavanam', 3, 9.5248000, 76.5247000),
            (28, 14, 'Pathamuttom', 4, 9.5004000, 76.5519000),
            (29, 14, 'Saintgits College', 5, 9.5100000, 76.5514000),
            (30, 14, 'Saintgits College of Engineering', 6, 9.5092100, 76.5518300);
        """)

        # 4. buses
        cursor.execute("""
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
        """)

        cursor.execute("""
            INSERT IGNORE INTO `buses` (`bus_id`, `bus_number`, `registration_number`, `route`, `driver_name`, `status`, `start_point`, `destination`, `driver_id`, `created_at`) VALUES
            (3, '11', NULL, 'Chengannur', 'Quality Driver', 'Active', NULL, NULL, 62, NOW()),
            (4, '12', NULL, 'Pala', 'Anil', 'Active', NULL, NULL, 8, NOW()),
            (6, '1', NULL, 'Thiruvalla', 'Benit', 'Active', NULL, NULL, 40, NOW()),
            (7, '10', NULL, 'Chengannur', 'Ben', 'Active', NULL, NULL, 6, NOW()),
            (8, '14', 'KL-05-AB-1414', 'Kottayam', 'Soman', 'Active', NULL, NULL, 66, NOW());
        """)

        # 5. parent_children
        cursor.execute("""
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
        """)

        cursor.execute("""
            INSERT IGNORE INTO `parent_children` (`child_id`, `parent_id`, `child_name`, `bus_id`, `route_id`, `pickup_stop_id`, `class_name`) VALUES
            (4, 15, 'Anjali', 6, 1, 1, '8'),
            (24, 65, 'Aneena', 8, 14, 30, '10th A');
        """)

        # 6. student_boarding
        cursor.execute("""
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
        """)

        # 7. driver_trips
        cursor.execute("""
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
        """)

        # 8. driver_locations
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS `driver_locations` (
              `location_id` int(11) NOT NULL AUTO_INCREMENT,
              `driver_id` int(11) NOT NULL,
              `latitude` decimal(10,7) NOT NULL,
              `longitude` decimal(10,7) NOT NULL,
              `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
              PRIMARY KEY (`location_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """)

        # 9. driver_emergencies
        cursor.execute("""
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
        """)

        # 10. parent_registration_requests
        cursor.execute("""
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
        """)

        # 11. driver_phone_otp
        cursor.execute("""
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
        """)

        # 12. assignment_logs
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS `assignment_logs` (
              `log_id` int(11) NOT NULL AUTO_INCREMENT,
              `entity_type` varchar(50) NOT NULL,
              `entity_id` int(11) DEFAULT NULL,
              `action` varchar(50) NOT NULL,
              `details` text DEFAULT NULL,
              `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
              PRIMARY KEY (`log_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """)

        # 13. child_bus_absence
        cursor.execute("""
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
        """)

        # 14. school_settings
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS `school_settings` (
              `id` int(11) NOT NULL AUTO_INCREMENT,
              `school_name` varchar(255) NOT NULL,
              `address` text NOT NULL,
              `latitude` double NOT NULL,
              `longitude` double NOT NULL,
              `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
              PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        """)

        cursor.execute("SELECT id FROM school_settings LIMIT 1")
        if not cursor.fetchone():
            cursor.execute("""
                INSERT INTO school_settings (id, school_name, address, latitude, longitude)
                VALUES (1, %s, %s, %s, %s)
            """, (
                "Saintgits College of Applied Sciences",
                "Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala – 686532",
                9.50921,
                76.55183
            ))

        conn.commit()
        _tables_ensured = True
    except Exception as e:
        print(f"Table auto-initialization note: {e}")
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

def ensure_school_table():
    ensure_all_tables()

def ensure_absence_table():
    ensure_all_tables()


def get_current_school_settings():
    ensure_school_table()
    conn = None
    cursor = None
    default_school = {
        "id": 1,
        "school_name": "Saintgits College of Applied Sciences",
        "address": "Kottukulam Hills, Pathamuttom P.O., Kottayam, Kerala – 686532",
        "latitude": 9.50921,
        "longitude": 76.55183
    }
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM school_settings ORDER BY id ASC LIMIT 1")
        row = cursor.fetchone()
        if row:
            return serialize_row(row)
    except Exception as e:
        print(f"Error fetching school settings: {e}")
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
    return default_school



# ============================================================
# HELPER
# ============================================================

def serialize_row(row):

    if not row:
        return row

    result = {}

    for key, value in row.items():

        if isinstance(value, datetime):
            result[key] = value.isoformat()

        elif isinstance(value, timedelta):
            tot_sec = int(value.total_seconds())
            hrs = (tot_sec // 3600) % 24
            mins = (tot_sec % 3600) // 60
            ampm = "AM" if hrs < 12 else "PM"
            hrs = hrs % 12
            if hrs == 0: hrs = 12
            result[key] = f"{hrs:02d}:{mins:02d} {ampm}"

        else:
            result[key] = value

    return result


def normalize_role(role):

    role_map = {
        "admin": "Admin",
        "driver": "Driver",
        "parent": "Parent"
    }

    role = str(role or "").strip()

    return role_map.get(role.lower(), role)


@app.before_request
def auto_init_tables():
    ensure_all_tables()


# ============================================================
# HOME
# ============================================================

@app.route("/", methods=["GET"])
def home():

    return jsonify({
        "success": True,
        "message": "RouteSafe backend is running"
    })


# ============================================================
# TEST DATABASE
# ============================================================

@app.route("/test-db", methods=["GET"])
def test_database():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor()

        cursor.execute("SELECT 1")
        

        result = cursor.fetchone()

        return jsonify({
            "success": True,
            "message": "Database connection successful",
            "result": result[0]
        })

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# REGISTER
#
# Parent registration:
#
# Parent enters:
# name
# email
# phone
# password
# child name
# class
# pickup stop
#
# Parent account becomes PENDING.
# Child is NOT assigned to a bus yet.
# ============================================================

@app.route("/register", methods=["POST"])
def register():

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        print("REGISTER REQUEST:")
        print(data)

        # ----------------------------------------------------
        # PARENT INFORMATION
        # ----------------------------------------------------

        full_name = str(
            data.get("full_name")
            or data.get("name")
            or ""
        ).strip()

        email = str(
            data.get("email")
            or ""
        ).strip().lower()

        phone = str(
            data.get("phone")
            or ""
        ).strip()

        password = str(
            data.get("password")
            or ""
        )

        role = normalize_role(data.get("role"))

        # ----------------------------------------------------
        # CHILD INFORMATION
        # ----------------------------------------------------

        child_name = str(
            data.get("child_name")
            or ""
        ).strip()

        class_name = str(
            data.get("class_name")
            or data.get("child_class")
            or data.get("class")
            or ""
        ).strip()

        pickup_stop_id = data.get("pickup_stop_id")

        # ----------------------------------------------------
        # VALIDATION
        # ----------------------------------------------------

        if not full_name:

            return jsonify({
                "success": False,
                "message": "Full name is required"
            }), 400

        if not email:

            return jsonify({
                "success": False,
                "message": "Email is required"
            }), 400

        if not password:

            return jsonify({
                "success": False,
                "message": "Password is required"
            }), 400

        if role not in ["Admin", "Driver", "Parent"]:

            return jsonify({
                "success": False,
                "message": "Invalid role"
            }), 400

        # Parent registration requires child information
        if role == "Parent" and not child_name:

            return jsonify({
                "success": False,
                "message": "Child name is required"
            }), 400

        # ----------------------------------------------------
        # DATABASE
        # ----------------------------------------------------

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # ----------------------------------------------------
        # CHECK EMAIL
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT user_id
            FROM users
            WHERE LOWER(TRIM(email)) = LOWER(TRIM(%s))
            LIMIT 1
            """,
            (email,)
        )

        existing = cursor.fetchone()

        if existing:

            return jsonify({
                "success": False,
                "message": "Email already registered"
            }), 409

        # ----------------------------------------------------
        # HASH PASSWORD
        # ----------------------------------------------------

        hashed_password = generate_password_hash(password)

        # ----------------------------------------------------
        # STATUS
        #
        # Parent = PENDING
        # Admin/Driver = APPROVED
        # ----------------------------------------------------

        if role in ["Parent", "Driver"]:
            account_status = "PENDING"
        else:
            account_status = "APPROVED"

        # ----------------------------------------------------
        # CREATE USER
        # ----------------------------------------------------

        cursor.execute(
            """
            INSERT INTO users (full_name, email, phone, password, role, status)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (full_name, email, phone, hashed_password, role, account_status)
        )
        parent_id = cursor.lastrowid

        # ----------------------------------------------------
        # STORE PARENT REGISTRATION REQUEST
        # ----------------------------------------------------

        if role == "Parent":

            cursor.execute(
                """
                INSERT INTO parent_registration_requests
                (full_name, email, phone, password, child_name, child_class, status)
                VALUES (%s, %s, %s, %s, %s, %s, 'PENDING')
                """,
                (full_name, email, phone, hashed_password, child_name, class_name)
            )

        conn.commit()

        if role == "Parent":

            return jsonify({
                "success": True,
                "message": "Registration submitted successfully. Waiting for admin approval.",
                "user_id": parent_id,
                "status": "PENDING"
            }), 201

        return jsonify({
            "success": True,
            "message": "Registration successful",
            "user_id": parent_id,
            "status": "APPROVED"
        }), 201

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        print("REGISTER DATABASE ERROR:", e)
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    except Exception as e:

        if conn:
            conn.rollback()

        print("REGISTER ERROR:", e)
        return jsonify({
            "success": False,
            "message": f"Server error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# LOGIN
#
# IMPORTANT:
# Parent can login ONLY if APPROVED.
# ============================================================

@app.route("/login", methods=["POST"])
def login():

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        print("")
        print("========================================")
        print("LOGIN REQUEST")
        print(data)
        print("========================================")
        

        email = str(
            data.get("email")
            or data.get("username")
            or ""
        ).strip().lower()

        password = str(
            data.get("password")
            or ""
        )

        requested_role = normalize_role(
            data.get("role")
        )

        if not email:

            return jsonify({
                "success": False,
                "message": "Email is required"
            }), 400

        if not password:

            return jsonify({
                "success": False,
                "message": "Password is required"
            }), 400

        if requested_role and requested_role not in [
            "Admin",
            "Driver",
            "Parent"
        ]:

            return jsonify({
                "success": False,
                "message": "Invalid role"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                email,
                phone,
                password,
                role,
                status
            FROM users
            WHERE LOWER(TRIM(email)) = LOWER(TRIM(%s))
            LIMIT 1
            """,
            (email,)
        )

        user = cursor.fetchone()

        if not user:

            return jsonify({
                "success": False,
                "message": "Invalid username or password"
            }), 401

        database_role = str(
            user.get("role") or ""
        ).strip()

        database_status = str(
            user.get("status") or "APPROVED"
        ).strip().upper()

        # ----------------------------------------------------
        # CHECK ROLE
        # ----------------------------------------------------

        if requested_role:

            if database_role.lower() != requested_role.lower():

                return jsonify({
                    "success": False,
                    "message": "Invalid username or password"
                }), 401

        # ----------------------------------------------------
        # DRIVER APPROVAL & BUS ASSIGNMENT CHECK
        # ----------------------------------------------------

        if database_role.lower() == "driver":

            if database_status == "PENDING":

                return jsonify({
                    "success": False,
                    "message": "Your Driver registration is pending Admin approval.",
                    "status": "PENDING",
                    "user": serialize_row(user)
                }), 403

            if database_status == "REJECTED":

                return jsonify({
                    "success": False,
                    "message": "Your Driver registration was rejected by the admin.",
                    "status": "REJECTED",
                    "user": serialize_row(user)
                }), 403

            if database_status != "APPROVED":

                return jsonify({
                    "success": False,
                    "message": "Your Driver account is not active.",
                    "status": database_status
                }), 403

            # Check assigned bus
            cursor.execute(
                """
                SELECT bus_id, bus_number
                FROM buses
                WHERE LOWER(TRIM(driver_name))= LOWER(TRIM(%s))LIMIT 1
                """,
                (user["full_name"],)
        )

            assigned_bus = cursor.fetchone()

            if not assigned_bus:

                return jsonify({
                    "success": False,
                    "message": "Your account is approved, but no bus has been assigned to you by the Admin yet.",
                    "status": "NO_BUS_ASSIGNED"
                }), 403

        # ----------------------------------------------------
        # PARENT APPROVAL CHECK
        # ----------------------------------------------------

        if database_role.lower() == "parent":

            if database_status == "PENDING":

                return jsonify({
                    "success": False,
                    "message": "Your account is waiting for admin approval.",
                    "status": "PENDING"
                }), 403

            if database_status == "REJECTED":

                return jsonify({
                    "success": False,
                    "message": "Your registration was rejected by the admin.",
                    "status": "REJECTED"
                }), 403

            if database_status != "APPROVED":

                return jsonify({
                    "success": False,
                    "message": "Your account is not active.",
                    "status": database_status
                }), 403

        # ----------------------------------------------------
        # PASSWORD CHECK
        # ----------------------------------------------------

        stored_password = str(
            user.get("password") or ""
        )

        password_valid = False

        try:

            password_valid = check_password_hash(
                stored_password,
                password
            )

        except Exception:

            password_valid = False

        # Support old plain-text passwords
        if not password_valid:

            if stored_password == password:
                password_valid = True

        if not password_valid:

            return jsonify({
                "success": False,
                "message": "Invalid username or password"
            }), 401

        # Never send password to Flutter
        user.pop("password", None)
        

        user = serialize_row(user)

        print("LOGIN SUCCESS")
        print(user)
        return jsonify({
            "success": True,
            "message": "Login successful",
            "user": user
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    except Exception as e:

        return jsonify({
            "success": False,
            "message": f"Server error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN
# GET PENDING PARENT REQUESTS
# ============================================================

# ============================================================
# ADMIN
# GET PENDING PARENT REQUESTS
# ============================================================

@app.route("/admin/parent-requests", methods=["GET"])
def get_parent_requests():

    conn = None
    cursor = None

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                COALESCE(pr.request_id, u.user_id) AS request_id,
                u.user_id,
                u.full_name,
                u.email,
                u.phone,
                COALESCE(pr.child_name, pc.child_name, 'Not provided') AS child_name,
                COALESCE(pr.child_class, pc.class_name, 'Not provided') AS child_class,
                u.status,
                u.created_at
            FROM users u
            LEFT JOIN parent_registration_requests pr
                ON LOWER(TRIM(u.email)) = LOWER(TRIM(pr.email))
            LEFT JOIN parent_children pc
                ON u.user_id = pc.parent_id
            WHERE u.role = 'Parent'
              AND (UPPER(TRIM(u.status)) = 'PENDING' OR (pr.status IS NOT NULL AND UPPER(TRIM(pr.status)) = 'PENDING'))
            GROUP BY u.user_id
            ORDER BY u.created_at DESC
            """
        )

        requests = cursor.fetchall() or []
        serialized_requests = [serialize_row(item) for item in requests]

        req_ids = [item.get("request_id") for item in serialized_requests]

        print("")
        print("==========================================")
        print("GET /admin/parent-requests EXECUTED")
        print("Database: routesafe_db")
        print(f"Pending requests count: {len(serialized_requests)}")
        print(f"Returned request_ids: {req_ids}")
        print("==========================================")
        print("")
        return jsonify({
            "success": True,
            "requests": serialized_requests
        }), 200

    except mysql.connector.Error as e:
        print(f"ERROR in GET /admin/parent-requests: {e}")
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN
# PENDING PARENT COUNT
# ============================================================

@app.route("/admin/parent-requests/count", methods=["GET"])
def get_pending_parent_count():

    conn = None
    cursor = None

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT COUNT(DISTINCT u.user_id) AS count
            FROM users u
            LEFT JOIN parent_registration_requests pr
                ON LOWER(TRIM(u.email)) = LOWER(TRIM(pr.email))
            WHERE u.role = 'Parent'
              AND (UPPER(TRIM(u.status)) = 'PENDING' OR (pr.status IS NOT NULL AND UPPER(TRIM(pr.status)) = 'PENDING'))
            """
        )
        result = cursor.fetchone()
        cnt = int(result["count"]) if result and result.get("count") is not None else 0

        return jsonify({
            "success": True,
            "count": cnt
        }), 200

    except mysql.connector.Error as e:
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN
# APPROVE PARENT
# ============================================================

@app.route(
    "/admin/parents/<int:parent_id>/approve",
    methods=["PUT"]
)
def approve_parent(parent_id):

    conn = None
    cursor = None

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # Retrieve pending request by request_id or email
        cursor.execute(
            """
            SELECT
                request_id,
                full_name,
                email,
                phone,
                password,
                child_name,
                child_class,
                status
            FROM parent_registration_requests
            WHERE request_id = %s
               OR LOWER(TRIM(email))IN (
                   SELECT LOWER(TRIM(email))
        FROM users
                   WHERE user_id = %s
               )
            LIMIT 1
            """,
            (parent_id, parent_id)
        )
        req = cursor.fetchone()

        if not req:
            return jsonify({
                "success": False,
                "message": f"Parent request {parent_id} not found"
            }), 404

        # Mark registration request as APPROVED
        cursor.execute(
            """
            UPDATE parent_registration_requests
            SET status = 'APPROVED'
            WHERE request_id = %s
            """,
            (req["request_id"],)
        )

        # Create or activate user in users table
        email = str(req["email"]).strip().lower()
        cursor.execute(
            """
            SELECT user_id
            FROM users
            WHERE LOWER(TRIM(email)) = %s
            LIMIT 1
            """,
            (email,)
        )
        existing_user = cursor.fetchone()

        if existing_user:
            parent_user_id = existing_user["user_id"]
            cursor.execute(
                "UPDATE users SET status = 'APPROVED' WHERE user_id = %s",
                (parent_user_id,)
            )
        else:
            cursor.execute(
                """
                INSERT INTO users (full_name, email, phone, password, role, status)
                VALUES (%s, %s, %s, %s, 'Parent', 'APPROVED')
                """,
                (
                    req["full_name"],
                    req["email"],
                    req["phone"],
                    req["password"],
                )
            )
            parent_user_id = cursor.lastrowid

        # Auto-link child into parent_children table using parent_user_id
        if req.get("child_name"):
            child_name = str(req["child_name"]).strip()
            class_name = str(req.get("child_class") or "").strip()

            cursor.execute(
                """
                SELECT child_id
                FROM parent_children
                WHERE parent_id = %s
                  AND LOWER(TRIM(child_name))= LOWER(TRIM(%s))LIMIT 1
                """,
                (parent_user_id, child_name)
        )
            existing_child = cursor.fetchone()

            if not existing_child:
                cursor.execute(
                    """
                    INSERT INTO parent_children (parent_id, child_name, class_name)
                    VALUES (%s, %s, %s)
                    """,
                    (parent_user_id, child_name, class_name)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Parent approved successfully",
            "request_id": req["request_id"],
            "parent_id": parent_user_id,
            "status": "APPROVED"
        }), 200

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN
# REJECT PARENT
# ============================================================

@app.route(
    "/admin/parents/<int:parent_id>/reject",
    methods=["PUT"]
)
def reject_parent(parent_id):

    conn = None
    cursor = None

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT request_id, email
            FROM parent_registration_requests
            WHERE request_id = %s
               OR LOWER(TRIM(email))IN (
                   SELECT LOWER(TRIM(email))
        FROM users
                   WHERE user_id = %s
               )
            LIMIT 1
            """,
            (parent_id, parent_id)
        )
        req = cursor.fetchone()

        if req:
            cursor.execute(
                """
                UPDATE parent_registration_requests
                SET status = 'REJECTED'
                WHERE request_id = %s
                """,
                (req["request_id"],)
        )
            cursor.execute(
                """
                UPDATE users
                SET status = 'REJECTED'
                WHERE LOWER(TRIM(email))= %s
                """,
                (str(req["email"]).strip().lower(),)
        )
        else:
            cursor.execute(
                """
                UPDATE users
                SET status = 'REJECTED'
                WHERE user_id = %s
                  AND role = 'Parent'
                """,
                (parent_id,)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Parent rejected successfully",
            "parent_id": parent_id,
            "status": "REJECTED"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# GET ALL ROUTES
# ============================================================

@app.route("/routes", methods=["GET"])
def get_routes():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                route_id,
                route_name
            FROM routes
            ORDER BY route_name ASC
            """
)
        
        routes = cursor.fetchall()

        return jsonify({
            "success": True,
            "routes": [
                serialize_row(route)
                for route in routes
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}",
            "routes": []
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# GET ALL BUSES
# ============================================================

@app.route("/buses", methods=["GET"])
def get_buses():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                bus_id,
                bus_number,
                route,
                driver_name,
                status
            FROM buses
            ORDER BY bus_id DESC
            """
)
        
        buses = cursor.fetchall()

        return jsonify({
            "success": True,
            "buses": [
                serialize_row(bus)
                for bus in buses
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}",
            "buses": []
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADD BUS
# ============================================================

@app.route("/buses", methods=["POST"])
def add_bus():

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        bus_number = str(
            data.get("bus_number")
            or ""
        ).strip()

        route = str(
            data.get("route")
            or ""
        ).strip()

        driver_name = str(
            data.get("driver_name")
            or ""
        ).strip()

        status = str(
            data.get("status")
            or "Active"
        ).strip()

        if not bus_number:

            return jsonify({
                "success": False,
                "message": "Bus number is required"
            }), 400

        if not route:

            return jsonify({
                "success": False,
                "message": "Route is required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT bus_id
            FROM buses
            WHERE bus_number = %s
            """,
            (bus_number,)
        )
        if cursor.fetchone():

            return jsonify({
                "success": False,
                "message": "Bus number already exists"
            }), 409

        cursor.execute(
            """
            INSERT INTO buses (bus_number, route, driver_name, status)
            VALUES (%s, %s, %s, %s)
            """,
            (bus_number, route, driver_name, status)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Bus added successfully",
            "bus_id": cursor.lastrowid
        }), 201

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# UPDATE BUS
# ============================================================

@app.route("/buses/<int:bus_id>", methods=["PUT"])
def update_bus(bus_id):

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        bus_number = str(
            data.get("bus_number")
            or ""
        ).strip()

        route = str(
            data.get("route")
            or ""
        ).strip()

        driver_name = str(
            data.get("driver_name")
            or ""
        ).strip()

        status = str(
            data.get("status")
            or "Active"
        ).strip()

        if not bus_number or not route:

            return jsonify({
                "success": False,
                "message": "Bus number and route are required"
            }), 400

        conn = get_db()
        cursor = conn.cursor()

        cursor.execute(
            """
            UPDATE buses
            SET bus_number = %s, route = %s, driver_name = %s, status = %s
            WHERE bus_id = %s
            """,
            (bus_number, route, driver_name, status, bus_id)
        )
        if cursor.rowcount == 0:

            return jsonify({
                "success": False,
                "message": "Bus not found"
            }), 404
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Bus updated successfully"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ASSIGN DRIVER TO BUS
# ============================================================

@app.route("/admin/buses/<int:bus_id>/assign-driver", methods=["PUT"])
@app.route("/buses/<int:bus_id>/assign-driver", methods=["PUT"])
def assign_bus_driver(bus_id):

    conn = None
    cursor = None

    try:
        data = request.get_json(silent=True) or {}
        driver_id = data.get("driver_id")
        
        driver_name = data.get("driver_name")
        

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        if driver_id:
            cursor.execute(
                "SELECT full_name FROM users WHERE user_id = %s AND role = 'Driver' LIMIT 1",
                (driver_id,)
            )
            d = cursor.fetchone()
            if d:
                driver_name = d["full_name"]

        if not driver_name:
            return jsonify({
                "success": False,
                "message": "Driver name or driver ID is required"
            }), 400

        cursor.execute(
            "UPDATE buses SET driver_name = %s WHERE bus_id = %s",
            (driver_name, bus_id)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Driver assigned to bus successfully",
            "bus_id": bus_id,
            "driver_name": driver_name
        }), 200

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DELETE BUS
# ============================================================

@app.route("/buses/<int:bus_id>", methods=["DELETE"])
def delete_bus(bus_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor()

        cursor.execute(
            """
            DELETE FROM buses
            WHERE bus_id = %s
            """,
            (bus_id,)
        )
        if cursor.rowcount == 0:

            return jsonify({
                "success": False,
                "message": "Bus not found"
            }), 404
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Bus deleted successfully"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DRIVER COUNT
# ============================================================

@app.route("/drivers/count", methods=["GET"])
def get_drivers_count():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT COUNT(*) AS count
            FROM users
            WHERE role = 'Driver'
            """
        )
        result = cursor.fetchone()

        return jsonify({
            "success": True,
            "count": int(result["count"])
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# GET DRIVERS
# ============================================================

@app.route("/drivers", methods=["GET"])
def get_drivers():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                email,
                phone,
                role,
                status
            FROM users
            WHERE role = 'Driver'
            ORDER BY user_id DESC
            """
)
        
        drivers = cursor.fetchall()

        return jsonify({
            "success": True,
            "drivers": [
                serialize_row(driver)
                for driver in drivers
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADD DRIVER
# ============================================================

@app.route("/drivers", methods=["POST"])
def add_driver():

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        full_name = str(
            data.get("full_name")
            or ""
        ).strip()

        email = str(
            data.get("email")
            or ""
        ).strip().lower()

        phone = str(
            data.get("phone")
            or ""
        ).strip()

        password = str(
            data.get("password")
            or ""

        )
        if not full_name or not email or not password:

            return jsonify({
                "success": False,
                "message": "Name, email and password are required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT user_id
            FROM users
            WHERE LOWER(TRIM(email))= LOWER(TRIM(%s))""",
            (email,)
        )
        if cursor.fetchone():

            return jsonify({
                "success": False,
                "message": "Email already exists"
            }), 409

        hashed_password = generate_password_hash(password)

        cursor.execute(
            """
            INSERT INTO users (full_name, email, phone, password, role, status)
            VALUES (%s, %s, %s, %s, 'Driver', 'APPROVED')
            """,
            (full_name, email, phone, hashed_password)
        )
        driver_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Driver added successfully",
            "driver_id": driver_id
        }), 201

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# UPDATE DRIVER
# ============================================================

@app.route("/drivers/<int:driver_id>", methods=["PUT"])
def update_driver(driver_id):

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        full_name = str(
            data.get("full_name")
            or ""
        ).strip()

        email = str(
            data.get("email")
            or ""
        ).strip().lower()

        phone = str(
            data.get("phone")
            or ""
        ).strip()

        password = data.get("password")

        if not full_name or not email:

            return jsonify({
                "success": False,
                "message": "Name and email are required"
            }), 400

        conn = get_db()
        cursor = conn.cursor()

        if password:

            hashed_password = generate_password_hash(str(password))
            cursor.execute(
                """
                UPDATE users
                SET full_name = %s, email = %s, phone = %s, password = %s
                WHERE user_id = %s AND role = 'Driver'
                """,
                (full_name, email, phone, hashed_password, driver_id)
            )

        else:
            cursor.execute(
                """
                UPDATE users
                SET full_name = %s, email = %s, phone = %s
                WHERE user_id = %s AND role = 'Driver'
                """,
                (full_name, email, phone, driver_id)
        )

        if cursor.rowcount == 0:
            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Driver updated successfully"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DELETE DRIVER
# ============================================================

@app.route("/drivers/<int:driver_id>", methods=["DELETE"])
def delete_driver(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor()

        cursor.execute(
            """
            DELETE FROM users
            WHERE user_id = %s
              AND role = 'Driver'
            """,
            (driver_id,)
        )

        if cursor.rowcount == 0:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Driver deleted successfully"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# GET PARENTS
# ============================================================

@app.route("/parents", methods=["GET"])
def get_parents():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                email,
                phone,
                role,
                status
            FROM users
            WHERE role = 'Parent'
            ORDER BY user_id DESC
            """
)
        
        parents = cursor.fetchall()

        return jsonify({
            "success": True,
            "parents": [
                serialize_row(parent)
                for parent in parents
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# PARENT COUNT
# ============================================================

@app.route("/parents/count", methods=["GET"])
def get_parents_count():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT COUNT(*) AS count
            FROM users
            WHERE role = 'Parent'
            """
        )
        result = cursor.fetchone()

        return jsonify({
            "success": True,
            "count": int(result["count"])
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADD PARENT FROM ADMIN
# ============================================================

@app.route("/parents", methods=["POST"])
def add_parent():

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        full_name = str(
            data.get("full_name")
            or ""
        ).strip()

        email = str(
            data.get("email")
            or ""
        ).strip().lower()

        phone = str(
            data.get("phone")
            or ""
        ).strip()

        password = str(
            data.get("password")
            or ""

        )
        if not full_name or not email or not password:

            return jsonify({
                "success": False,
                "message": "Name, email and password are required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT user_id
            FROM users
            WHERE LOWER(TRIM(email))= LOWER(TRIM(%s))""",
            (email,)
        )
        if cursor.fetchone():

            return jsonify({
                "success": False,
                "message": "Email already exists"
            }), 409

        hashed_password = generate_password_hash(password)

        cursor.execute(
            """
            INSERT INTO users (full_name, email, phone, password, role, status)
            VALUES (%s, %s, %s, %s, 'Parent', 'APPROVED')
            """,
            (full_name, email, phone, hashed_password)
        )
        parent_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Parent added successfully",
            "parent_id": parent_id
        }), 201

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# UPDATE PARENT
# ============================================================

@app.route("/parents/<int:parent_id>", methods=["PUT"])
def update_parent(parent_id):

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        full_name = str(
            data.get("full_name")
            or ""
        ).strip()

        email = str(
            data.get("email")
            or ""
        ).strip().lower()

        phone = str(
            data.get("phone")
            or ""
        ).strip()

        password = data.get("password")

        if not full_name or not email:

            return jsonify({
                "success": False,
                "message": "Name and email are required"
            }), 400

        conn = get_db()
        cursor = conn.cursor()

        if password:
            hashed_password = generate_password_hash(str(password))
            cursor.execute(
                """
                UPDATE users
                SET full_name = %s, email = %s, phone = %s, password = %s
                WHERE user_id = %s AND role = 'Parent'
                """,
                (full_name, email, phone, hashed_password, parent_id)
        )
        else:
            cursor.execute(
                """
                UPDATE users
                SET full_name = %s, email = %s, phone = %s
                WHERE user_id = %s AND role = 'Parent'
                """,
                (full_name, email, phone, parent_id)
        )

        if cursor.rowcount == 0:
            return jsonify({
                "success": False,
                "message": "Parent not found"
            }), 404

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Parent updated successfully"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DELETE PARENT
# ============================================================

@app.route("/parents/<int:parent_id>", methods=["DELETE"])
def delete_parent(parent_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor()

        cursor.execute(
            """
            DELETE FROM users
            WHERE user_id = %s AND role = 'Parent'
            """,
            (parent_id,)
        )

        if cursor.rowcount == 0:
            return jsonify({
                "success": False,
                "message": "Parent not found"
            }), 404

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Parent deleted successfully"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN DASHBOARD
# ============================================================

@app.route("/admin/dashboard", methods=["GET"])
@app.route("/admin/dashboard/metrics", methods=["GET"])
@app.route("/admin/dashboard-metrics", methods=["GET"])
def get_admin_dashboard():

    conn = None
    cursor = None

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT COUNT(*) AS count FROM buses")
        total_buses = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM users WHERE role = 'Driver' AND status = 'APPROVED'")
        total_drivers = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM users WHERE role = 'Parent' AND status = 'APPROVED'")
        total_parents = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM parent_children")
        total_students = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM driver_trips WHERE status = 'Active'")
        active_trips = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM users WHERE role = 'Driver' AND status = 'PENDING'")
        pending_drivers = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM parent_registration_requests WHERE status = 'PENDING'")
        pending_parents = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM routes")
        total_routes = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM driver_emergencies WHERE status = 'Pending'")
        pending_emergencies = cursor.fetchone()["count"]

        metrics_dict = {
            "total_buses": int(total_buses or 0),
            "total_drivers": int(total_drivers or 0),
            "total_parents": int(total_parents or 0),
            "total_students": int(total_students or 0),
            "total_children": int(total_students or 0),
            "active_trips": int(active_trips or 0),
            "pending_drivers": int(pending_drivers or 0),
            "pending_parents": int(pending_parents or 0),
            "total_routes": int(total_routes or 0),
            "pending_emergencies": int(pending_emergencies or 0),
        }

        res_payload = {"success": True, "metrics": metrics_dict, "dashboard": metrics_dict}
        res_payload.update(metrics_dict)

        return jsonify(res_payload), 200

    except mysql.connector.Error as e:
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# ============================================================
# ADMIN - GET PARENTS
# ============================================================

@app.route("/admin/parents", methods=["GET"])
def get_admin_parents():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                email,
                phone,
                status
            FROM users
            WHERE role = 'Parent'
            ORDER BY full_name ASC
            """
)
        
        parents = cursor.fetchall()

        return jsonify({
            "success": True,
            "parents": parents
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}",
            "parents": []
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN - GET CHILDREN
# ============================================================

@app.route("/admin/children", methods=["GET"])
def get_admin_children():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                pc.child_id,
                pc.parent_id,

                u.full_name AS parent_name,
                u.email AS parent_email,
                u.phone AS parent_phone,

                pc.child_name,
                pc.class_name,

                pc.bus_id,
                b.bus_number,
                COALESCE(u_driver.full_name, b.driver_name, 'Not Assigned') AS driver_name,
                u_driver.phone AS driver_phone,

                pc.route_id,
                r.route_name,

                pc.pickup_stop_id,
                ps.stop_name

            FROM parent_children pc

            LEFT JOIN users u
                ON pc.parent_id = u.user_id

            LEFT JOIN buses b
                ON pc.bus_id = b.bus_id

            LEFT JOIN users u_driver
                ON (b.driver_id = u_driver.user_id OR LOWER(TRIM(b.driver_name)) = LOWER(TRIM(u_driver.full_name)))
               AND u_driver.role = 'Driver'

            LEFT JOIN routes r
                ON pc.route_id = r.route_id

            LEFT JOIN pickup_stops ps
                ON pc.pickup_stop_id = ps.stop_id

            ORDER BY pc.child_id DESC
            """
        )
        children = cursor.fetchall()

        return jsonify({
            "success": True,
            "children": [
                serialize_row(child)
                for child in children
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}",
            "children": []
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN - GET PICKUP STOPS
# ============================================================

@app.route("/routes/<int:route_id>/stops", methods=["GET"])
@app.route("/parent/stops", methods=["GET"])
@app.route("/admin/stops", methods=["GET"])
def get_admin_stops(route_id=None):

    conn = None
    cursor = None

    try:
        if not route_id:
            route_id = request.args.get("route_id")

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        if route_id:

            cursor.execute(
                """
                SELECT stop_id, route_id, stop_name, stop_order, latitude, longitude
                FROM pickup_stops
                WHERE route_id = %s
                ORDER BY stop_order ASC, stop_id ASC
                """,
                (route_id,)
            )
        else:
            cursor.execute(
                """
                SELECT stop_id, route_id, stop_name, stop_order, latitude, longitude
                FROM pickup_stops
                ORDER BY route_id ASC, stop_order ASC
                """
            )
        
        stops = cursor.fetchall()

        return jsonify({
            "success": True,
            "stops": [
                serialize_row(stop)
                for stop in stops
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}",
            "stops": []
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN - LINK CHILD
#
# This is separate from bus assignment.
#
# Parent -> Child
# ============================================================

@app.route("/admin/children/link", methods=["POST"])
def link_child():

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        parent_id = data.get("parent_id")
        

        child_name = str(
            data.get("child_name")
            or ""
        ).strip()

        class_name = str(
            data.get("class_name")
            or data.get("class")
            or ""
        ).strip()

        if not parent_id:

            return jsonify({
                "success": False,
                "message": "Parent is required"
            }), 400

        if not child_name:

            return jsonify({
                "success": False,
                "message": "Child name is required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # ----------------------------------------------------
        # PARENT CHECK
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                status
            FROM users
            WHERE user_id = %s
              AND role = 'Parent'
            """,
            (parent_id,)
        )
        parent = cursor.fetchone()

        if not parent:

            return jsonify({
                "success": False,
                "message": "Parent not found"
            }), 404

        if str(parent["status"]).upper() != "APPROVED":

            return jsonify({
                "success": False,
                "message": "Parent must be approved before linking a child"
            }), 400

        # ----------------------------------------------------
        # INSERT CHILD
        # ----------------------------------------------------

        cursor.execute(
            """
            INSERT INTO parent_children (parent_id, child_name, class_name)
            VALUES (%s, %s, %s)
            """,
            (parent_id, child_name, class_name)
        )
        child_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Child linked successfully",
            "child": {
                "child_id": child_id,
                "parent_id": parent_id,
                "parent_name": parent["full_name"],
                "child_name": child_name,
                "class_name": class_name
            }
        }), 201

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN - ASSIGN CHILD
#
# Child -> Bus -> Route -> Stop
# ============================================================

@app.route("/admin/children/<int:child_id>/assign", methods=["PUT"])
def assign_child_transport(child_id):

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        bus_id = data.get("bus_id")
        
        route_id = data.get("route_id")
        
        pickup_stop_id = data.get("pickup_stop_id")

        if not bus_id:
            return jsonify({
                "success": False,
                "message": "Bus is required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # ----------------------------------------------------
        # CHILD CHECK
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                child_id,
                parent_id,
                child_name,
                class_name,
                bus_id,
                route_id,
                pickup_stop_id
            FROM parent_children
            WHERE child_id = %s
            """,
            (child_id,)
        )
        child = cursor.fetchone()

        if not child:
            return jsonify({
                "success": False,
                "message": "Child not found"
            }), 404

        # Fallback for route_id and pickup_stop_id
        final_route_id = route_id or child.get("route_id")
        
        final_stop_id = pickup_stop_id or child.get("pickup_stop_id")

        # ----------------------------------------------------
        # BUS CHECK
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                bus_id,
                bus_number,
                route,
                driver_name,
                status
            FROM buses
            WHERE bus_id = %s
            """,
            (bus_id,)
        )
        bus = cursor.fetchone()

        if not bus:
            return jsonify({
                "success": False,
                "message": "Bus not found"
            }), 404

        # ----------------------------------------------------
        # ASSIGN
        # ----------------------------------------------------

        cursor.execute(
            """
            UPDATE parent_children
            SET bus_id = %s, route_id = %s, pickup_stop_id = %s
            WHERE child_id = %s
            """,
            (bus_id, final_route_id, final_stop_id, child_id)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Child transport assignment successful",
            "assignment": {
                "child_id": child_id,
                "child_name": child["child_name"],
                "bus_id": bus["bus_id"],
                "bus_number": bus["bus_number"],
                "driver_name": bus["driver_name"],
                "route_id": final_route_id,
                "pickup_stop_id": final_stop_id
            }
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN - OLD ASSIGN CHILD ENDPOINT
#
# Kept for compatibility with your existing Flutter screen.
#
# It can:
# Parent + Child + Bus + Route + Stop
# in one request.
# ============================================================

@app.route("/admin/children", methods=["POST"])
def assign_child():

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        parent_id = data.get("parent_id")
        

        child_name = str(
            data.get("child_name")
            or ""
        ).strip()

        class_name = str(
            data.get("class_name")
            or data.get("class")
            or ""
        ).strip()

        bus_id = data.get("bus_id")
        
        route_id = data.get("route_id")
        
        pickup_stop_id = data.get("pickup_stop_id")

        if not parent_id:

            return jsonify({
                "success": False,
                "message": "Parent is required"
            }), 400

        if not child_name:

            return jsonify({
                "success": False,
                "message": "Child name is required"
            }), 400

        if not bus_id:

            return jsonify({
                "success": False,
                "message": "Bus is required"
            }), 400

        if not route_id:

            return jsonify({
                "success": False,
                "message": "Route is required"
            }), 400

        if not pickup_stop_id:

            return jsonify({
                "success": False,
                "message": "Pickup stop is required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # Parent
        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                status
            FROM users
            WHERE user_id = %s
              AND role = 'Parent'
            """,
            (parent_id,)
        )
        parent = cursor.fetchone()

        if not parent:

            return jsonify({
                "success": False,
                "message": "Parent not found"
            }), 404

        if str(parent["status"]).upper() != "APPROVED":

            return jsonify({
                "success": False,
                "message": "Parent is not approved"
            }), 400

        # Bus
        cursor.execute(
            """
            SELECT
                bus_id,
                bus_number,
                route,
                driver_name,
                status
            FROM buses
            WHERE bus_id = %s
            """,
            (bus_id,)
        )
        bus = cursor.fetchone()

        if not bus:

            return jsonify({
                "success": False,
                "message": "Bus not found"
            }), 404

        # Route
        cursor.execute(
            """
            SELECT
                route_id,
                route_name
            FROM routes
            WHERE route_id = %s
            """,
            (route_id,)
        )
        route = cursor.fetchone()

        if not route:

            return jsonify({
                "success": False,
                "message": "Route not found"
            }), 404

        # Stop
        cursor.execute(
            """
            SELECT stop_id, route_id, stop_name, stop_order, latitude, longitude
            FROM pickup_stops
            WHERE stop_id = %s AND route_id = %s
            """,
            (pickup_stop_id, route_id)
        )
        stop = cursor.fetchone()

        if not stop:
            return jsonify({
                "success": False,
                "message": "Pickup stop not found for selected route"
            }), 404

        # Insert
        cursor.execute(
            """
            INSERT INTO parent_children (parent_id, child_name, class_name, bus_id, route_id, pickup_stop_id)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (parent_id, child_name, class_name, bus_id, route_id, pickup_stop_id)
        )
        child_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Child assigned successfully",
            "child": {
                "child_id": child_id,
                "parent_id": parent_id,
                "parent_name": parent["full_name"],
                "child_name": child_name,
                "class_name": class_name,
                "bus_id": bus_id,
                "bus_number": bus["bus_number"],
                "driver_name": bus["driver_name"],
                "route_id": route_id,
                "route_name": route["route_name"],
                "pickup_stop_id": pickup_stop_id,
                "pickup_stop_name": stop["stop_name"]
            }
        }), 201

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN - GET CHILD ASSIGNMENT DETAILS
# ============================================================

@app.route("/admin/children/details", methods=["GET"])
def get_child_assignment_details():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT

                pc.child_id,
                pc.parent_id,

                u.full_name AS parent_name,
                u.email AS parent_email,

                pc.child_name,
                pc.class_name,

                pc.bus_id,
                b.bus_number,
                b.driver_name,
                b.status AS bus_status,

                pc.route_id,
                r.route_name,

                pc.pickup_stop_id,
                ps.stop_name,
                ps.stop_order,
                ps.latitude,
                ps.longitude

            FROM parent_children pc

            LEFT JOIN users u
                ON pc.parent_id = u.user_id

            LEFT JOIN buses b
                ON pc.bus_id = b.bus_id

            LEFT JOIN routes r
                ON pc.route_id = r.route_id

            LEFT JOIN pickup_stops ps
                ON pc.pickup_stop_id = ps.stop_id

            ORDER BY pc.child_id DESC
            """
)
        
        children = cursor.fetchall()

        return jsonify({
            "success": True,
            "children": [
                serialize_row(child)
                for child in children
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}",
            "children": []
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ADMIN - DELETE CHILD
# ============================================================

@app.route("/admin/children/<int:child_id>", methods=["DELETE"])
def delete_child(child_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor()

        cursor.execute(
            """
            DELETE FROM parent_children
            WHERE child_id = %s
            """,
            (child_id,)
        )

        if cursor.rowcount == 0:
            return jsonify({
                "success": False,
                "message": "Child not found"
            }), 404

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Child assignment deleted successfully"
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# ============================================================
@app.route("/parent/<int:parent_id>/child", methods=["POST"])
@app.route("/parent/children", methods=["POST"])
def add_parent_child(parent_id=None):

    conn = None
    cursor = None

    try:
        data = request.get_json(silent=True) or {}

        if not parent_id:
            parent_id = data.get("parent_id")
        

        child_id = data.get("child_id")
        
        child_name = str(data.get("child_name") or "").strip()
        class_name = str(data.get("class_name") or data.get("class") or "").strip()
        pickup_stop_id = data.get("pickup_stop_id")

        if not parent_id:
            return jsonify({
                "success": False,
                "message": "Parent ID is required"
            }), 400

        if not pickup_stop_id:
            return jsonify({
                "success": False,
                "message": "Pickup stop is required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # Retrieve route_id from pickup_stop
        route_id = None
        cursor.execute(
            "SELECT route_id FROM pickup_stops WHERE stop_id = %s LIMIT 1",
            (pickup_stop_id,)
        )
        stop_row = cursor.fetchone()
        if stop_row:
            route_id = stop_row["route_id"]

        # Check if parent already has an existing child record
        existing_child = None
        if child_id:
            cursor.execute(
                "SELECT * FROM parent_children WHERE child_id = %s AND parent_id = %s LIMIT 1",
                (child_id, parent_id)
            )
            existing_child = cursor.fetchone()

        if not existing_child and child_name:
            cursor.execute(
                "SELECT * FROM parent_children WHERE parent_id = %s AND LOWER(TRIM(child_name))= LOWER(TRIM(%s))LIMIT 1",
                (parent_id, child_name)
            )
            existing_child = cursor.fetchone()

        if not existing_child:
            cursor.execute(
                "SELECT * FROM parent_children WHERE parent_id = %s ORDER BY child_id ASC LIMIT 1",
                (parent_id,)
            )
            existing_child = cursor.fetchone()

        if existing_child:
            target_child_id = existing_child["child_id"]
            final_child_name = child_name or existing_child["child_name"]
            final_class_name = class_name or existing_child["class_name"]

            cursor.execute(
                """
                UPDATE parent_children
                SET pickup_stop_id = %s,
                    route_id = COALESCE(%s, route_id),
                    child_name = %s,
                    class_name = %s
                WHERE child_id = %s
                """,
                (pickup_stop_id, route_id, final_child_name, final_class_name, target_child_id)
            )
            conn.commit()

            return jsonify({
                "success": True,
                "message": "Child pickup stop updated successfully",
                "child_id": target_child_id,
                "child": {
                    "child_id": target_child_id,
                    "parent_id": parent_id,
                    "child_name": final_child_name,
                    "class_name": final_class_name,
                    "pickup_stop_id": pickup_stop_id,
                    "route_id": route_id,
                    "bus_id": existing_child.get("bus_id")
                }
            }), 200
        else:
            if not child_name:
                return jsonify({
                    "success": False,
                    "message": "Child name is required"
                }), 400

            cursor.execute(
                """
                INSERT INTO parent_children (parent_id, child_name, class_name, pickup_stop_id, route_id, bus_id)
                VALUES (%s, %s, %s, %s, %s, NULL)
                """,
                (parent_id, child_name, class_name, pickup_stop_id, route_id)
        )

            new_child_id = cursor.lastrowid
            conn.commit()

            return jsonify({
                "success": True,
                "message": "Child pickup stop saved successfully",
                "child_id": new_child_id,
                "child": {
                    "child_id": new_child_id,
                    "parent_id": parent_id,
                    "child_name": child_name,
                    "class_name": class_name,
                    "pickup_stop_id": pickup_stop_id,
                    "route_id": route_id,
                    "bus_id": None
                }
            }), 201

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:
        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# PARENT - SAVE PICKUP STOP FOR CHILD
# ============================================================

@app.route("/parent/<int:parent_id>/child/<int:child_id>/stop", methods=["POST", "PUT"])
@app.route("/parent/child/stop", methods=["POST", "PUT"])
def update_parent_child_stop(parent_id=None, child_id=None):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        if not parent_id:
            parent_id = data.get("parent_id")
        if not child_id:
            child_id = data.get("child_id")
        stop_id = data.get("stop_id") or data.get("pickup_stop_id")

        if not parent_id or not child_id or not stop_id:
            return jsonify({
                "success": False,
                "message": "Parent ID, Child ID, and Pickup Stop ID are required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # 1. Verify child exists and belongs to logged-in parent
        cursor.execute(
            "SELECT * FROM parent_children WHERE child_id = %s AND parent_id = %s LIMIT 1",
            (child_id, parent_id)
        )
        child = cursor.fetchone()
        if not child:
            return jsonify({
                "success": False,
                "message": "Child record not found for this parent"
            }), 404

        # 2. Determine target route_id
        req_route_id = data.get("route_id")
        
        cursor.execute(
            "SELECT * FROM pickup_stops WHERE stop_id = %s LIMIT 1",
            (stop_id,)
        )
        stop_row = cursor.fetchone()
        if not stop_row:
            return jsonify({
                "success": False,
                "message": "Selected pickup stop does not exist"
            }), 400

        target_route_id = req_route_id or stop_row.get("route_id") or child.get("route_id")

        if req_route_id and stop_row.get("route_id") and int(stop_row["route_id"]) != int(req_route_id):
            return jsonify({
                "success": False,
                "message": "Selected pickup stop does not belong to the selected route"
            }), 400

        # 3. Save selected pickup_stop_id and route_id
        cursor.execute(
            "UPDATE parent_children SET pickup_stop_id = %s, route_id = %s WHERE child_id = %s AND parent_id = %s",
            (stop_id, target_route_id, child_id, parent_id)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Route and pickup stop request submitted to admin successfully",
            "child_id": child_id,
            "route_id": target_route_id,
            "pickup_stop_id": stop_id,
            "stop_name": stop_row.get("stop_name")
        }), 200

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# ============================================================
# PARENT DASHBOARD
# ============================================================

@app.route(
    "/parent/<int:parent_id>/dashboard",
    methods=["GET"]
)
def get_parent_dashboard(parent_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # ----------------------------------------------------
        # PARENT CHECK
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                email,
                phone,
                status
            FROM users
            WHERE user_id = %s
              AND role = 'Parent'
            """,
            (parent_id,)
        )
        parent = cursor.fetchone()

        if not parent:

            return jsonify({
                "success": False,
                "message": "Parent not found"
            }), 404

        if str(parent["status"]).upper() != "APPROVED":

            return jsonify({
                "success": False,
                "message": "Parent account is not approved",
                "status": parent["status"]
            }), 403

        # ----------------------------------------------------
        # CHILDREN + BUS + DRIVER (NAME & PHONE) + ROUTE + STOP
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT
                pc.child_id,
                pc.child_name,
                pc.class_name,

                pc.bus_id,
                b.bus_number,
                COALESCE(u_driver.full_name, b.driver_name, 'Not Assigned') AS driver_name,
                u_driver.phone AS driver_phone,
                b.status AS bus_status,

                pc.route_id AS route_id,
                COALESCE(r.route_name, b.route, 'Not Assigned') AS route_name,

                pc.pickup_stop_id,
                ps.stop_name,
                ps.stop_order,
                ps.latitude,
                ps.longitude,

                cba.absence_id IS NOT NULL AND cba.status = 'Not Riding Today' AS is_absent,
                COALESCE(sb.boarding_status, CASE WHEN cba.absence_id IS NOT NULL AND cba.status = 'Not Riding Today' THEN 'SKIP' ELSE 'Not Boarded' END) AS boarding_status,
                sb.boarding_time

            FROM parent_children pc

            LEFT JOIN buses b
                ON pc.bus_id = b.bus_id

            LEFT JOIN users u_driver
                ON (b.driver_id = u_driver.user_id OR LOWER(TRIM(b.driver_name)) = LOWER(TRIM(u_driver.full_name)))
               AND u_driver.role = 'Driver'

            LEFT JOIN routes r
                ON (pc.route_id = r.route_id OR LOWER(TRIM(b.route)) = LOWER(TRIM(r.route_name)))

            LEFT JOIN pickup_stops ps
                ON pc.pickup_stop_id = ps.stop_id

            LEFT JOIN child_bus_absence cba
                ON pc.child_id = cba.child_id AND cba.absence_date = CURDATE()

            LEFT JOIN student_boarding sb
                ON pc.child_id = sb.child_id AND sb.attendance_date = CURDATE()

            WHERE pc.parent_id = %s

            GROUP BY pc.child_id
            ORDER BY pc.child_id ASC
            """,
            (parent_id,)
        )
        children = cursor.fetchall() or []

        processed_children = []
        for child in children:
            child_dict = serialize_row(child)
            bus_id = child_dict.get("bus_id")

            trip_status = "Not Started"
            eta = "ETA: Not available"
            active_trip = None

            if bus_id:
                # Check for active trip for this bus
                cursor.execute(
                    """
                    SELECT dt.trip_id, dt.driver_id, dl.latitude AS driver_lat, dl.longitude AS driver_lng
                    FROM driver_trips dt
                    LEFT JOIN (
                        SELECT dl1.driver_id, dl1.latitude, dl1.longitude
                        FROM driver_locations dl1
                        INNER JOIN (
                            SELECT driver_id, MAX(location_id) AS max_loc_id
                            FROM driver_locations
                            GROUP BY driver_id
                        ) latest ON dl1.location_id = latest.max_loc_id
                    ) dl ON dt.driver_id = dl.driver_id
                    WHERE dt.bus_id = %s AND dt.status = 'Active'
                    ORDER BY dt.trip_id DESC
                    LIMIT 1
                    """,
                    (bus_id,)
                )
                active_trip = cursor.fetchone()

                if active_trip:
                    trip_status = "On Route"
                    driver_lat = active_trip.get("driver_lat")
                    driver_lng = active_trip.get("driver_lng")
                    stop_lat = child_dict.get("latitude")
                    stop_lng = child_dict.get("longitude")

                    if driver_lat and driver_lng:
                        try:
                            import math
                            lat1, lon1 = float(driver_lat), float(driver_lng)
                            school_data = get_current_school_settings()
                            sch_lat, sch_lng = float(school_data["latitude"]), float(school_data["longitude"])
                            
                            # Distance to school
                            dlat_s = math.radians(sch_lat - lat1)
                            dlon_s = math.radians(sch_lng - lon1)
                            a_s = math.sin(dlat_s / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(sch_lat)) * math.sin(dlon_s / 2)**2
                            c_s = 2 * math.atan2(math.sqrt(a_s), math.sqrt(1 - a_s))
                            mins_school = max(1, int((6371 * c_s / 30.0) * 60))
                            
                            if stop_lat and stop_lng:
                                lat2, lon2 = float(stop_lat), float(stop_lng)
                                dlat = math.radians(lat2 - lat1)
                                dlon = math.radians(lon2 - lon1)
                                a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
                                c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
                                mins_pickup = max(1, int((6371 * c / 30.0) * 60))
                                eta = f"{mins_pickup} min (Pickup) • {mins_school} min (School)"
                            else:
                                eta = f"{mins_school} min (School Arrival)"
                        except Exception:
                            eta = "ETA: Not available"
                    else:
                        eta = "ETA: Not available"
                else:
                    trip_status = "Not Started"
                    eta = "ETA: Not available"
            else:
                trip_status = "Not Started"
                eta = "ETA: Not available"

            is_absent = bool(child_dict.get("is_absent"))
            child_dict["is_absent"] = is_absent
            child_dict["bus_today_status"] = "NOT RIDING TODAY" if is_absent else "RIDING TODAY"
            child_dict["trip_started"] = bool(active_trip)
            child_dict["trip_status"] = trip_status
            child_dict["eta"] = eta
            processed_children.append(child_dict)

        return jsonify({
            "success": True,
            "parent": serialize_row(parent),
            "children": processed_children,
            "school": get_current_school_settings()
        }), 200

    except mysql.connector.Error as e:
        print("PARENT DASHBOARD DATABASE ERROR:", e)
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# ============================================================
# PARENT CHILDREN
# ============================================================

@app.route(
    "/parent/<int:parent_id>/children",
    methods=["GET"]
)
def get_parent_children(parent_id):

    conn = None
    cursor = None

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                pc.child_id,
                pc.child_name,
                pc.class_name,

                pc.bus_id,
                b.bus_number,
                COALESCE(u_driver.full_name, b.driver_name, 'Not Assigned') AS driver_name,
                u_driver.phone AS driver_phone,

                COALESCE(pc.route_id, r.route_id) AS route_id,
                COALESCE(r.route_name, b.route, 'Not Assigned') AS route_name,

                pc.pickup_stop_id,
                ps.stop_name,
                ps.latitude,
                ps.longitude,

                COALESCE(sb.boarding_status, 'Not Boarded') AS boarding_status,
                sb.boarding_time

            FROM parent_children pc

            LEFT JOIN buses b
                ON pc.bus_id = b.bus_id

            LEFT JOIN users u_driver
                ON u_driver.user_id = CASE
                    WHEN b.driver_id IS NOT NULL AND b.driver_id > 0 THEN b.driver_id
                    ELSE (SELECT u2.user_id FROM users u2 WHERE LOWER(TRIM(u2.full_name)) = LOWER(TRIM(b.driver_name)) AND u2.role = 'Driver' ORDER BY u2.user_id DESC LIMIT 1)
                END

            LEFT JOIN routes r
                ON r.route_id = CASE
                    WHEN pc.route_id IS NOT NULL AND pc.route_id > 0 THEN pc.route_id
                    ELSE (SELECT r2.route_id FROM routes r2 WHERE LOWER(TRIM(r2.route_name)) = LOWER(TRIM(b.route)) ORDER BY r2.route_id DESC LIMIT 1)
                END

            LEFT JOIN pickup_stops ps
                ON pc.pickup_stop_id = ps.stop_id

            LEFT JOIN student_boarding sb
                ON pc.child_id = sb.child_id AND sb.attendance_date = CURDATE()

            WHERE pc.parent_id = %s
            GROUP BY pc.child_id
            ORDER BY pc.child_id ASC
            """,
            (parent_id,)
        )
        children = cursor.fetchall() or []

        return jsonify({
            "success": True,
            "children": [
                serialize_row(child)
                for child in children
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# PARENT LIVE BUS LOCATION
# ============================================================

@app.route(
    "/parent/<int:parent_id>/child/<int:child_id>/location",
    methods=["GET"]
)
def get_parent_child_location(parent_id, child_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # ----------------------------------------------------
        # Verify child belongs to parent
        # ----------------------------------------------------

        cursor.execute(
            """
            SELECT

                pc.child_id,
                pc.child_name,
                pc.class_name,
                pc.bus_id,

                b.bus_number,
                b.driver_name,
                d.phone AS driver_phone,
                d.user_id AS driver_id,

                pc.route_id,
                r.route_name,

                pc.pickup_stop_id,
                ps.stop_name,

                b.status AS bus_status

            FROM parent_children pc

            LEFT JOIN buses b
                ON pc.bus_id = b.bus_id

            LEFT JOIN users d
                ON (b.driver_id = d.user_id OR LOWER(TRIM(d.full_name)) = LOWER(TRIM(b.driver_name)))
               AND d.role = 'Driver'

            LEFT JOIN routes r
                ON pc.route_id = r.route_id

            LEFT JOIN pickup_stops ps
                ON pc.pickup_stop_id = ps.stop_id

            WHERE pc.child_id = %s
              AND pc.parent_id = %s
            """,
            (child_id, parent_id)
        )
        child = cursor.fetchone()

        if not child:

            return jsonify({
                "success": False,
                "message": "Child not found for this parent"
            }), 404

        # ----------------------------------------------------
        # No bus assigned
        # ----------------------------------------------------

        if not child["bus_id"]:

            return jsonify({
                "success": True,
                "message": "No bus assigned to this child",
                "child": serialize_row(child),
                "location": None
            }), 200

        # ----------------------------------------------------
        # No driver
        # ----------------------------------------------------

        if not child["driver_id"]:

            return jsonify({
                "success": True,
                "message": "No driver assigned to this bus",
                "child": serialize_row(child),
                "location": None
            }), 200

        # ----------------------------------------------------
        # CHECK ACTIVE TRIP STATUS & ROUTE STOPS
        # ----------------------------------------------------

        is_trip_active = False
        if child.get("driver_id"):
            cursor.execute(
                """
                SELECT trip_id
                FROM driver_trips
                WHERE driver_id = %s
                  AND status = 'Active'
                ORDER BY trip_id DESC
                LIMIT 1
                """,
                (child["driver_id"],)
            )
            active_trip = cursor.fetchone()
            if active_trip:
                is_trip_active = True

        route_stops = []
        if child.get("route_id"):
            cursor.execute(
                """
                SELECT stop_id, route_id, stop_name, stop_order, latitude, longitude
                FROM pickup_stops
                WHERE route_id = %s
                ORDER BY stop_order ASC, stop_id ASC
                """,
                (child["route_id"],)
            )
            route_stops = cursor.fetchall() or []

        # ----------------------------------------------------
        # LATEST DRIVER LOCATION
        # ----------------------------------------------------

        location = None
        if child.get("driver_id"):
            cursor.execute(
                """
                SELECT
                    driver_id,
                    latitude,
                    longitude,
                    updated_at
                FROM driver_locations
                WHERE driver_id = %s
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                (child["driver_id"],)
            )
            location = cursor.fetchone()

        # ----------------------------------------------------
        # TODAY'S STUDENT BOARDING STATUS
        # ----------------------------------------------------
        boarding_info = None
        cursor.execute(
            """
            SELECT boarding_status, boarding_time
            FROM student_boarding
            WHERE child_id = %s AND attendance_date = CURDATE()
            LIMIT 1
            """,
            (child_id,)
        )
        b_row = cursor.fetchone()
        if b_row:
            boarding_info = serialize_row(b_row)

        child_data = serialize_row(child)
        if child_data:
            if boarding_info:
                child_data["boarding_status"] = boarding_info.get("boarding_status")
                child_data["boarding_time"] = boarding_info.get("boarding_time")
            else:
                child_data["boarding_status"] = "Not Boarded"
                child_data["boarding_time"] = None

        return jsonify({
            "success": True,
            "child": child_data,
            "is_trip_active": is_trip_active,
            "location": (
                serialize_row(location)
                if (location and is_trip_active)
                else None
            ),
            "stops": [serialize_row(s) for s in route_stops]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DRIVER DASHBOARD
# ============================================================

@app.route(
    "/driver/<int:driver_id>/dashboard",
    methods=["GET"]
)
def get_driver_dashboard(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                user_id,
                full_name,
                email,
                phone,
                role,
                status
            FROM users
            WHERE user_id = %s
              AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        cursor.execute(
            """
            SELECT
                bus_id,
                bus_number,
                route,
                driver_name,
                status
            FROM buses
            WHERE driver_id = %s OR LOWER(TRIM(driver_name)) = LOWER(TRIM(%s))
            ORDER BY bus_id DESC
            LIMIT 1
            """,
            (driver_id, driver["full_name"],)
        )
        bus = cursor.fetchone()

        children = []
        if bus and bus.get("bus_id"):
            cursor.execute(
                """
                SELECT
                    pc.child_id,
                    pc.child_name,
                    pc.class_name,
                    pc.bus_id,
                    b.bus_number,
                    pc.route_id,
                    r.route_name,
                    pc.pickup_stop_id,
                    ps.stop_name,
                    ps.latitude AS stop_latitude,
                    ps.longitude AS stop_longitude,
                    COALESCE(sb.boarding_status, 'Not Boarded') AS boarding_status,
                    sb.boarding_time,
                    u_parent.full_name AS parent_name,
                    u_parent.phone AS parent_phone,
                    u_parent.email AS parent_email
                FROM parent_children pc
                LEFT JOIN buses b
                    ON pc.bus_id = b.bus_id
                LEFT JOIN routes r
                    ON pc.route_id = r.route_id
                LEFT JOIN pickup_stops ps
                    ON pc.pickup_stop_id = ps.stop_id
                LEFT JOIN users u_parent
                    ON pc.parent_id = u_parent.user_id
                LEFT JOIN student_boarding sb
                    ON pc.child_id = sb.child_id AND sb.attendance_date = CURDATE()
                WHERE pc.bus_id = %s OR (pc.bus_id IS NULL AND LOWER(TRIM(r.route_name)) = LOWER(TRIM(%s)))
                GROUP BY pc.child_id
                ORDER BY pc.child_name ASC
                """,
                (bus["bus_id"], bus.get("route"))
            )
            children = cursor.fetchall() or []

        return jsonify({
            "success": True,
            "driver": serialize_row(driver),
            "bus": (
                serialize_row(bus)
                if bus
                else None
            ),
            "children": [
                serialize_row(c)
                for c in children
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DRIVER BUS
# ============================================================

@app.route(
    "/driver/<int:driver_id>/bus",
    methods=["GET"]
)
def get_driver_bus(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT full_name
            FROM users
            WHERE user_id = %s
              AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        cursor.execute(
            """
            SELECT
                bus_id,
                bus_number,
                route,
                driver_name,
                status
            FROM buses
            WHERE driver_id = %s OR LOWER(TRIM(driver_name)) = LOWER(TRIM(%s))
            ORDER BY bus_id DESC
            LIMIT 1
            """,
            (driver_id, driver["full_name"])
        )
        bus = cursor.fetchone()

        return jsonify({
            "success": True,
            "bus": (
                serialize_row(bus)
                if bus
                else None
            )
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# START DRIVER TRIP
# ============================================================

@app.route(
    "/driver/<int:driver_id>/trip/start",
    methods=["POST"]
)
def start_driver_trip(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                user_id,
                full_name
            FROM users
            WHERE user_id = %s
              AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        cursor.execute(
            """
            SELECT
                bus_id,
                bus_number,
                route,
                driver_name,
                status
            FROM buses
            WHERE driver_id = %s OR LOWER(TRIM(driver_name)) = LOWER(TRIM(%s))
            ORDER BY bus_id DESC
            LIMIT 1
            """,
            (driver_id, driver["full_name"])
        )
        bus = cursor.fetchone()

        if not bus:

            return jsonify({
                "success": False,
                "message": "No bus assigned to this driver"
            }), 400

        cursor.execute(
            """
            SELECT trip_id
            FROM driver_trips
            WHERE driver_id = %s
              AND status = 'Active'
            ORDER BY trip_id DESC
            LIMIT 1
            """,
            (driver_id,)
        )
        active_trip = cursor.fetchone()

        if active_trip:

            return jsonify({
                "success": True,
                "message": "Trip is already active",
                "trip_id": active_trip["trip_id"],
                "bus": {
                    "bus_id": bus["bus_id"],
                    "bus_number": bus["bus_number"],
                    "route": bus["route"]
                }
            }), 200

        cursor.execute(
            """
            INSERT INTO driver_trips
            (
                driver_id,
                bus_id,
                start_time,
                status
            )
            VALUES
            (
                %s,
                %s,
                NOW(),
                'Active'
            )
            """,
            (
                driver_id,
                bus["bus_id"]
            )
        )

        trip_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Trip started successfully",
            "trip_id": trip_id,
            "bus": {
                "bus_id": bus["bus_id"],
                "bus_number": bus["bus_number"],
                "route": bus["route"]
            }
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# END DRIVER TRIP
# ============================================================

@app.route(
    "/driver/<int:driver_id>/trip/end",
    methods=["POST"]
)
def end_driver_trip(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                trip_id
            FROM driver_trips
            WHERE driver_id = %s
              AND status = 'Active'
            ORDER BY trip_id DESC
            LIMIT 1
            """,
            (driver_id,)
        )
        trip = cursor.fetchone()

        if not trip:

            return jsonify({
                "success": False,
                "message": "No active trip found"
            }), 400

        cursor.execute(
            """
            UPDATE driver_trips
            SET
                end_time = NOW(),
                status = 'Completed'
            WHERE trip_id = %s
            """,
            (trip["trip_id"],)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Trip ended successfully",
            "trip_id": trip["trip_id"]
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# UPDATE DRIVER LOCATION
# ============================================================

@app.route(
    "/driver/<int:driver_id>/location",
    methods=["POST"]
)
def update_driver_location(driver_id):

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        latitude = data.get("latitude")
        
        longitude = data.get("longitude")

        if latitude is None or longitude is None:

            return jsonify({
                "success": False,
                "message": "Latitude and longitude are required"
            }), 400

        try:

            latitude = float(latitude)
        
            longitude = float(longitude)

        except (ValueError, TypeError):

            return jsonify({
                "success": False,
                "message": "Invalid latitude or longitude"
            }), 400

        if latitude < -90 or latitude > 90:

            return jsonify({
                "success": False,
                "message": "Invalid latitude"
            }), 400

        if longitude < -180 or longitude > 180:

            return jsonify({
                "success": False,
                "message": "Invalid longitude"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT user_id
            FROM users
            WHERE user_id = %s
              AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        cursor.execute(
            """
            INSERT INTO driver_locations
            (
                driver_id,
                latitude,
                longitude
            )
            VALUES
            (
                %s,
                %s,
                %s
            )
            """,
            (
                driver_id,
                latitude,
                longitude
            )
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Driver location updated successfully",
            "location": {
                "driver_id": driver_id,
                "latitude": latitude,
                "longitude": longitude
            }
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# GET DRIVER LOCATION
# ============================================================

@app.route(
    "/driver/<int:driver_id>/location",
    methods=["GET"]
)
def get_driver_location(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT user_id
            FROM users
            WHERE user_id = %s
              AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        cursor.execute(
            """
            SELECT
                driver_id,
                latitude,
                longitude,
                updated_at
            FROM driver_locations
            WHERE driver_id = %s
            ORDER BY updated_at DESC
            LIMIT 1
            """,
            (driver_id,)
        )
        location = cursor.fetchone()

        return jsonify({
            "success": True,
            "location": (
                serialize_row(location)
                if location
                else None
            )
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DRIVER EMERGENCY
# ============================================================

@app.route(
    "/driver/<int:driver_id>/emergency",
    methods=["POST"]
)
def report_driver_emergency(driver_id):

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}

        message = str(
            data.get("message")
            or ""
        ).strip()

        if not message:

            return jsonify({
                "success": False,
                "message": "Emergency message is required"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT user_id
            FROM users
            WHERE user_id = %s
              AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        emergency_type = str(data.get("emergency_type") or data.get("type") or "Other").strip()
        latitude = data.get("latitude")
        
        longitude = data.get("longitude")
        
        bus_id = data.get("bus_id")

        cursor.execute(
            """
            INSERT INTO driver_emergencies
            (
                driver_id,
                emergency_type,
                message,
                latitude,
                longitude,
                bus_id,
                status
            )
            VALUES
            (
                %s, %s, %s, %s, %s, %s, 'Pending'
            )
            """,
            (
                driver_id,
                emergency_type,
                message,
                latitude,
                longitude,
                bus_id
            )
        )

        emergency_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Emergency report submitted successfully",
            "emergency_id": emergency_id
        }), 201

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DRIVER TRIP HISTORY
# ============================================================

@app.route(
    "/driver/<int:driver_id>/trips",
    methods=["GET"]
)
def get_driver_trips(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                t.trip_id,
                t.driver_id,
                t.bus_id,
                b.bus_number,
                b.route,
                t.start_time,
                t.end_time,
                t.status
            FROM driver_trips t

            LEFT JOIN buses b
                ON t.bus_id = b.bus_id

            WHERE t.driver_id = %s

            ORDER BY t.trip_id DESC
            """,
            (driver_id,)
        )
        trips = cursor.fetchall()

        return jsonify({
            "success": True,
            "trips": [
                serialize_row(trip)
                for trip in trips
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# DRIVER EMERGENCIES
# ============================================================

@app.route(
    "/driver/<int:driver_id>/emergencies",
    methods=["GET"]
)
def get_driver_emergencies(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                emergency_id,
                driver_id,
                COALESCE(emergency_type, 'Other') AS emergency_type,
                message,
                latitude,
                longitude,
                bus_id,
                status,
                created_at
            FROM driver_emergencies

            WHERE driver_id = %s

            ORDER BY emergency_id DESC
            """,
            (driver_id,)
        )
        emergencies = cursor.fetchall()

        return jsonify({
            "success": True,
            "emergencies": [
                serialize_row(item)
                for item in emergencies
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# RUN SERVER
# ============================================================



# ============================================================
# DRIVER PHONE CHANGE 2FA (EMAIL OTP)
# ============================================================

def send_otp_email(to_email, driver_name, otp):
    mail_server = os.environ.get("MAIL_SERVER", "smtp.gmail.com")
        
    mail_port = int(os.environ.get("MAIL_PORT", 587))
    mail_username = os.environ.get("MAIL_USERNAME", "")
        
    mail_password = os.environ.get("MAIL_PASSWORD", "")
        
    mail_from = os.environ.get("MAIL_FROM", mail_username or "noreply@routesafe.com")
        
    use_tls = os.environ.get("MAIL_USE_TLS", "true").lower() in ("true", "1", "yes")
        

    subject = "RouteSafe - Phone Number Change Verification"
    body = (
        f"Hello {driver_name},\n\n"
        f"Your RouteSafe verification code is:\n\n"
        f"    {otp}\n\n"
        f"This code expires in 5 minutes.\n\n"
        f"If you did not request this change, please ignore this email.\n"
    )

    if not mail_username or not mail_password:
        print(f"[MAIL NOTICE] SMTP credentials not set in environment. Verification OTP for {to_email} created successfully.")
        return True, "Code generated (SMTP not configured)"

    try:
        msg = MIMEMultipart()
        msg["From"] = mail_from
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain"))
        server = smtplib.SMTP(mail_server, mail_port, timeout=10)
        if use_tls:
            server.starttls()
        server.login(mail_username, mail_password)
        server.send_message(msg)
        server.quit()
        return True, "Email sent successfully"
    except Exception as e:
        print(f"[MAIL ERROR] Failed to send OTP email to {to_email}: {e}")
        return False, f"Failed to send email: {e}"


def init_otp_table():
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS driver_phone_otp (
            otp_id INT AUTO_INCREMENT PRIMARY KEY,
            driver_id INT NOT NULL,
            new_phone VARCHAR(20) NOT NULL,
            otp_hash VARCHAR(255) NOT NULL,
            expires_at DATETIME NOT NULL,
            attempts INT DEFAULT 0,
            verified TINYINT(1) DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (driver_id) REFERENCES users(user_id) ON DELETE CASCADE
        );
        """)
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error initializing driver_phone_otp table: {e}")

try:
    init_otp_table()
except Exception:
    pass


@app.route("/driver/<int:driver_id>/phone-change/request", methods=["POST"])
def request_driver_phone_change(driver_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        new_phone = str(data.get("new_phone") or "").strip()

        if not new_phone:
            return jsonify({
                "success": False,
                "message": "New phone number is required"
            }), 400

        clean_phone = re.sub(r'[\s\-\(\)\+]', '', new_phone)
        if not (clean_phone.isdigit() and 7 <= len(clean_phone) <= 15):
            return jsonify({
                "success": False,
                "message": "Please enter a valid phone number (7 to 15 digits)"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT user_id, full_name, email, phone, role FROM users WHERE user_id = %s LIMIT 1",
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver or str(driver["role"]).capitalize() != "Driver":
            return jsonify({
                "success": False,
                "message": "Driver account not found"
            }), 404

        if driver.get("phone") and str(driver["phone"]).strip() == new_phone:
            return jsonify({
                "success": False,
                "message": "New phone number is the same as current phone number"
            }), 400

        # Check 60s cooldown
        cursor.execute(
            """
            SELECT created_at FROM driver_phone_otp
            WHERE driver_id = %s AND verified = 0 AND expires_at > NOW()
            ORDER BY otp_id DESC LIMIT 1
            """,
            (driver_id,)
        )
        last_otp = cursor.fetchone()
        if last_otp and last_otp.get("created_at"):
            created_at = last_otp["created_at"]
            if isinstance(created_at, datetime):
                elapsed = (datetime.now() - created_at).total_seconds()
                if elapsed < 60:
                    remaining = int(60 - elapsed)
                    return jsonify({
                        "success": False,
                        "message": f"Please wait {remaining} seconds before requesting a new code"
                    }), 429

        # Invalidate previous unverified OTPs
        cursor.execute(
            "UPDATE driver_phone_otp SET verified = 1 WHERE driver_id = %s AND verified = 0",
            (driver_id,)
        )

        otp = f"{random.randint(100000, 999999)}"
        otp_hash = generate_password_hash(otp)
        
        expires_at = datetime.now() + timedelta(minutes=5)

        cursor.execute(
            """
            INSERT INTO driver_phone_otp (driver_id, new_phone, otp_hash, expires_at, attempts, verified)
            VALUES (%s, %s, %s, %s, 0, 0)
            """,
            (driver_id, new_phone, otp_hash, expires_at)
        )
        conn.commit()

        send_otp_email(driver["email"], driver["full_name"], otp)
        return jsonify({
            "success": True,
            "message": f"Verification code sent to your registered email ({driver['email']})"
        }), 200

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "message": f"Error: {e}"
        }), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


@app.route("/driver/<int:driver_id>/phone-change/verify", methods=["POST"])
def verify_driver_phone_change(driver_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        otp_input = str(data.get("otp") or "").strip()

        if not otp_input or not otp_input.isdigit() or len(otp_input) != 6:
            return jsonify({
                "success": False,
                "message": "Verification code must be exactly 6 digits"
            }), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT user_id, full_name, email, role FROM users WHERE user_id = %s LIMIT 1",
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver or str(driver["role"]).capitalize() != "Driver":
            return jsonify({
                "success": False,
                "message": "Driver account not found"
            }), 404

        cursor.execute(
            """
            SELECT * FROM driver_phone_otp
            WHERE driver_id = %s AND verified = 0
            ORDER BY otp_id DESC LIMIT 1
            """,
            (driver_id,)
        )
        otp_record = cursor.fetchone()

        if not otp_record:
            return jsonify({
                "success": False,
                "message": "No active verification request found. Please request a new code."
            }), 404

        expires_at = otp_record["expires_at"]
        if isinstance(expires_at, datetime) and datetime.now() > expires_at:
            return jsonify({
                "success": False,
                "message": "Verification code expired. Request a new code."
            }), 400

        attempts = int(otp_record.get("attempts") or 0)
        if attempts >= 3:
            return jsonify({
                "success": False,
                "message": "Too many invalid attempts. Please request a new code."
            }), 400

        attempts += 1
        cursor.execute(
            "UPDATE driver_phone_otp SET attempts = %s WHERE otp_id = %s",
            (attempts, otp_record["otp_id"])
        )
        conn.commit()

        if not check_password_hash(otp_record["otp_hash"], otp_input):
            remaining = 3 - attempts
            msg = "Invalid verification code"
            if remaining > 0:
                msg += f". {remaining} attempt(s) remaining."
            else:
                msg += ". Attempt limit reached. Request a new code."
            return jsonify({
                "success": False,
                "message": msg
            }), 400

        new_phone = otp_record["new_phone"]

        cursor.execute(
            "UPDATE driver_phone_otp SET verified = 1 WHERE otp_id = %s",
            (otp_record["otp_id"],)
        )
        cursor.execute(
            "UPDATE users SET phone = %s WHERE user_id = %s AND role = 'Driver'",
            (new_phone, driver_id)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Phone number updated successfully",
            "phone": new_phone
        }), 200

    except mysql.connector.Error as e:
        if conn:
            conn.rollback()
        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500
    except Exception as e:
        return jsonify({
            "success": False,
            "message": f"Error: {e}"
        }), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()





# ============================================================
# PARENT ABSENCE & DYNAMIC ITINERARY ENDPOINTS
# ============================================================

@app.route("/parent/<int:parent_id>/child/<int:child_id>/absence", methods=["POST"])
def mark_child_absent(parent_id, child_id):
    ensure_absence_table()
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        absence_date = data.get("absence_date") or datetime.now().strftime("%Y-%m-%d")

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT user_id, status FROM users WHERE user_id = %s AND role = 'Parent'", (parent_id,))
        parent = cursor.fetchone()
        if not parent or str(parent.get("status")).upper() != "APPROVED":
            return jsonify({"success": False, "message": "Unauthorized or unapproved parent account"}), 403

        cursor.execute(
            "SELECT pc.child_id, pc.child_name, pc.bus_id, pc.route_id, pc.pickup_stop_id FROM parent_children pc WHERE pc.child_id = %s AND pc.parent_id = %s",
            (child_id, parent_id)
        )
        child = cursor.fetchone()
        if not child:
            return jsonify({"success": False, "message": "Child not found for this parent"}), 404

        if child.get("bus_id"):
            cursor.execute(
                """
                SELECT dt.trip_id
                FROM driver_trips dt
                WHERE dt.bus_id = %s AND dt.status = 'Active' AND DATE(dt.start_time) = %s
                LIMIT 1
                """,
                (child["bus_id"], absence_date)
            )
            if cursor.fetchone():
                return jsonify({
                    "success": False,
                    "message": "The trip has already started. Today's absence can no longer be changed."
                }), 400

        cursor.execute(
            """
            INSERT INTO child_bus_absence (child_id, parent_id, route_id, stop_id, absence_date, status)
            VALUES (%s, %s, %s, %s, %s, 'Not Riding Today')
            ON DUPLICATE KEY UPDATE status = 'Not Riding Today', updated_at = CURRENT_TIMESTAMP
            """,
            (child_id, parent_id, child.get("route_id"), child.get("pickup_stop_id"), absence_date)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": f"{child['child_name']} marked as Not Riding Today",
            "is_absent": True,
            "status": "Not Riding Today"
        }), 200

    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/parent/<int:parent_id>/child/<int:child_id>/absence/cancel", methods=["POST"])
@app.route("/parent/<int:parent_id>/child/<int:child_id>/absence", methods=["DELETE"])
def cancel_child_absence(parent_id, child_id):
    ensure_absence_table()
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        absence_date = data.get("absence_date") or datetime.now().strftime("%Y-%m-%d")

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT pc.child_id, pc.child_name, pc.bus_id FROM parent_children pc WHERE pc.child_id = %s AND pc.parent_id = %s",
            (child_id, parent_id)
        )
        child = cursor.fetchone()
        if not child:
            return jsonify({"success": False, "message": "Child not found for this parent"}), 404

        if child.get("bus_id"):
            cursor.execute(
                "SELECT dt.trip_id FROM driver_trips dt WHERE dt.bus_id = %s AND dt.status = 'Active' AND DATE(dt.start_time) = %s LIMIT 1",
                (child["bus_id"], absence_date)
            )
            if cursor.fetchone():
                return jsonify({
                    "success": False,
                    "message": "The trip has already started. Today's absence can no longer be changed."
                }), 400

        cursor.execute("DELETE FROM child_bus_absence WHERE child_id = %s AND absence_date = %s", (child_id, absence_date))
        conn.commit()

        return jsonify({
            "success": True,
            "message": f"Absence for {child['child_name']} cancelled successfully",
            "is_absent": False,
            "status": "Riding Today"
        }), 200

    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/parent/<int:parent_id>/child/<int:child_id>/absence", methods=["GET"])
def get_child_absence_status(parent_id, child_id):
    ensure_absence_table()
    conn = None
    cursor = None
    try:
        absence_date = request.args.get("date") or datetime.now().strftime("%Y-%m-%d")

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT pc.child_id, pc.child_name, pc.bus_id FROM parent_children pc WHERE pc.child_id = %s AND pc.parent_id = %s", (child_id, parent_id))
        child = cursor.fetchone()
        if not child:
            return jsonify({"success": False, "message": "Child not found"}), 404

        cursor.execute("SELECT * FROM child_bus_absence WHERE child_id = %s AND absence_date = %s", (child_id, absence_date))
        absence = cursor.fetchone()

        trip_started = False
        if child.get("bus_id"):
            cursor.execute("SELECT trip_id FROM driver_trips WHERE bus_id = %s AND status = 'Active' AND DATE(start_time) = %s LIMIT 1", (child["bus_id"], absence_date))
            if cursor.fetchone():
                trip_started = True

        is_absent = bool(absence and absence.get("status") == "Not Riding Today")

        return jsonify({
            "success": True,
            "is_absent": is_absent,
            "status": "Not Riding Today" if is_absent else "Riding Today",
            "trip_started": trip_started,
            "absence": serialize_row(absence) if absence else None
        }), 200

    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/driver/<int:driver_id>/itinerary", methods=["GET"])
def get_driver_active_itinerary(driver_id):
    ensure_absence_table()
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT full_name FROM users WHERE user_id = %s AND role = 'Driver'", (driver_id,))
        driver = cursor.fetchone()
        if not driver:
            return jsonify({"success": False, "message": "Driver not found"}), 404

        cursor.execute(
            "SELECT bus_id, bus_number, route, registration_number, start_point, destination FROM buses WHERE driver_id = %s OR LOWER(TRIM(driver_name)) = LOWER(TRIM(%s)) LIMIT 1",
            (driver_id, driver["full_name"])
        )
        bus = cursor.fetchone()
        if not bus:
            return jsonify({"success": True, "bus": None, "all_stops": [], "active_stops": [], "skipped_stops": [], "students": []}), 200

        stops = []
        if bus.get("route"):
            cursor.execute(
                """
                SELECT ps.stop_id, ps.stop_name, ps.stop_order, ps.latitude, ps.longitude
                FROM pickup_stops ps
                JOIN routes r ON ps.route_id = r.route_id
                WHERE LOWER(TRIM(r.route_name)) = LOWER(TRIM(%s))
                ORDER BY ps.stop_order ASC
                """,
                (bus["route"],)
            )
            stops = cursor.fetchall() or []

        cursor.execute(
            """
            SELECT
                pc.child_id,
                pc.child_name,
                pc.class_name,
                pc.parent_id,
                u.full_name AS parent_name,
                u.phone AS parent_phone,
                pc.pickup_stop_id,
                ps.stop_name,
                ps.latitude AS stop_latitude,
                ps.longitude AS stop_longitude,
                cba.absence_id IS NOT NULL AND cba.status = 'Not Riding Today' AS is_absent,
                COALESCE(sb.boarding_status, CASE WHEN cba.absence_id IS NOT NULL AND cba.status = 'Not Riding Today' THEN 'SKIP' ELSE 'Not Boarded' END) AS boarding_status
            FROM parent_children pc
            LEFT JOIN users u ON pc.parent_id = u.user_id
            LEFT JOIN pickup_stops ps ON pc.pickup_stop_id = ps.stop_id
            LEFT JOIN routes r ON pc.route_id = r.route_id
            LEFT JOIN child_bus_absence cba ON pc.child_id = cba.child_id AND cba.absence_date = CURDATE()
            LEFT JOIN student_boarding sb ON pc.child_id = sb.child_id AND sb.attendance_date = CURDATE()
            WHERE pc.bus_id = %s OR (pc.bus_id IS NULL AND LOWER(TRIM(r.route_name)) = LOWER(TRIM(%s)))
            GROUP BY pc.child_id
            ORDER BY pc.child_name ASC
            """,
            (bus["bus_id"], bus.get("route"))
        )
        students = cursor.fetchall() or []

        active_stops = []
        skipped_stops = []

        for stop in stops:
            sid = stop["stop_id"]
            stop_students = [s for s in students if s.get("pickup_stop_id") == sid]
            stop_dict = serialize_row(stop)
            if stop_students and all(s.get("is_absent") for s in stop_students):
                stop_dict["is_skipped"] = True
                stop_dict["skip_reason"] = "Child is not riding today"
                skipped_stops.append(stop_dict)
            else:
                stop_dict["is_skipped"] = False
                active_stops.append(stop_dict)

        return jsonify({
            "success": True,
            "bus": serialize_row(bus),
            "all_stops": [serialize_row(s) for s in stops],
            "active_stops": active_stops,
            "skipped_stops": skipped_stops,
            "students": [serialize_row(s) for s in students]
        }), 200

    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


# ============================================================
# DRIVER MODULE EXTENSION ENDPOINTS
# ============================================================

@app.route("/driver/<int:driver_id>/status", methods=["GET"])
def get_driver_status(driver_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            """
            SELECT user_id, full_name, email, phone, role, status, account_status, created_at
            FROM users
            WHERE user_id = %s AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()
        if not driver:
            return jsonify({"success": False, "message": "Driver not found"}), 404

        status = driver.get("status") or driver.get("account_status") or "PENDING"
        
        bus_info = None
        if status == "APPROVED":
            cursor.execute(
                """
                SELECT bus_id, bus_number, registration_number, route, start_point, destination, status
                FROM buses
                WHERE driver_id = %s OR driver_name = %s
                LIMIT 1
                """,
                (driver_id, driver["full_name"])
            )
            bus_info = cursor.fetchone()

        return jsonify({
            "success": True,
            "status": status,
            "driver": serialize_row(driver),
            "bus": serialize_row(bus_info) if bus_info else None
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/driver/<int:driver_id>/bus", methods=["GET"])
def get_driver_bus_details(driver_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        
        # Get driver full name
        cursor.execute("SELECT full_name FROM users WHERE user_id = %s AND role = 'Driver'", (driver_id,))
        driver = cursor.fetchone()
        if not driver:
            return jsonify({"success": False, "message": "Driver not found"}), 404
            
        cursor.execute(
            """
            SELECT bus_id, bus_number, registration_number, route, start_point, destination, status, driver_name
            FROM buses
            WHERE driver_id = %s OR driver_name = %s
            LIMIT 1
            """,
            (driver_id, driver["full_name"])
        )
        bus = cursor.fetchone()
        if not bus:
            return jsonify({"success": False, "message": "No bus assigned to driver"}), 444
            
        # Get route stops if route exists
        stops = []
        if bus.get("route"):
            cursor.execute(
                """
                SELECT ps.stop_id, ps.stop_name, ps.stop_order, ps.latitude, ps.longitude
                FROM pickup_stops ps
                JOIN routes r ON ps.route_id = r.route_id
                WHERE r.route_name = %s
                ORDER BY ps.stop_order ASC
                """,
                (bus["route"],)
            )
            stops = cursor.fetchall()

        return jsonify({
            "success": True,
            "bus": serialize_row(bus),
            "stops": [serialize_row(s) for s in stops]
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/driver/<int:driver_id>/students", methods=["GET"])
@app.route("/driver/<int:driver_id>/boarding", methods=["GET"])
def get_driver_assigned_students(driver_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        
        cursor.execute("SELECT full_name FROM users WHERE user_id = %s AND role = 'Driver'", (driver_id,))
        driver = cursor.fetchone()
        if not driver:
            return jsonify({"success": False, "message": "Driver not found"}), 404

        cursor.execute(
            "SELECT bus_id, route FROM buses WHERE driver_id = %s OR LOWER(TRIM(driver_name)) = LOWER(TRIM(%s)) LIMIT 1",
            (driver_id, driver["full_name"])
        )
        bus = cursor.fetchone()
        if not bus:
            return jsonify({"success": True, "students": [], "boarding": []}), 200

        cursor.execute(
            """
            SELECT 
                pc.child_id,
                pc.child_name,
                pc.class_name,
                pc.parent_id,
                u.full_name AS parent_name,
                u.phone AS parent_phone,
                u.email AS parent_email,
                pc.pickup_stop_id,
                ps.stop_name,
                ps.latitude AS stop_latitude,
                ps.longitude AS stop_longitude,
                cba.absence_id IS NOT NULL AND cba.status = 'Not Riding Today' AS is_absent,
                COALESCE(sb.boarding_status, CASE WHEN cba.absence_id IS NOT NULL AND cba.status = 'Not Riding Today' THEN 'SKIP' ELSE 'Not Boarded' END) AS boarding_status,
                sb.boarding_time
            FROM parent_children pc
            LEFT JOIN users u ON pc.parent_id = u.user_id
            LEFT JOIN pickup_stops ps ON pc.pickup_stop_id = ps.stop_id
            LEFT JOIN routes r ON pc.route_id = r.route_id
            LEFT JOIN child_bus_absence cba ON pc.child_id = cba.child_id AND cba.absence_date = CURDATE()
            LEFT JOIN student_boarding sb ON pc.child_id = sb.child_id AND sb.attendance_date = CURDATE()
            WHERE pc.bus_id = %s OR (pc.bus_id IS NULL AND LOWER(TRIM(r.route_name)) = LOWER(TRIM(%s)))
            GROUP BY pc.child_id
            ORDER BY pc.child_name ASC
            """,
            (bus["bus_id"], bus.get("route"))
        )
        students = cursor.fetchall()
        serialized_students = []
        for s in students:
            row_dict = serialize_row(s)
            if row_dict.get("is_absent") and row_dict.get("boarding_status") != "Boarded":
                row_dict["boarding_status"] = "SKIP"
                row_dict["absence_reason"] = "Not Riding Today"
            serialized_students.append(row_dict)
        return jsonify({
            "success": True,
            "students": serialized_students,
            "boarding": serialized_students
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/driver/<int:driver_id>/boarding/update", methods=["POST"])
def update_student_boarding(driver_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        child_id = data.get("child_id")
        boarding_status = str(data.get("boarding_status") or "Boarded").strip()

        if not child_id:
            return jsonify({"success": False, "message": "child_id is required"}), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT full_name FROM users WHERE user_id = %s AND role = 'Driver'", (driver_id,))
        driver = cursor.fetchone()
        if not driver:
            return jsonify({"success": False, "message": "Driver not found"}), 404

        cursor.execute(
            "SELECT bus_id, route FROM buses WHERE driver_id = %s OR LOWER(TRIM(driver_name)) = LOWER(TRIM(%s)) ORDER BY bus_id DESC LIMIT 1",
            (driver_id, driver["full_name"])
        )
        bus = cursor.fetchone()
        if not bus:
            return jsonify({"success": False, "message": "No bus assigned to driver"}), 400

        cursor.execute(
            """
            SELECT pc.child_id, pc.pickup_stop_id 
            FROM parent_children pc
            LEFT JOIN routes r ON pc.route_id = r.route_id
            WHERE pc.child_id = %s AND (pc.bus_id = %s OR pc.bus_id IS NULL OR LOWER(TRIM(r.route_name)) = LOWER(TRIM(%s)))
            """,
            (child_id, bus["bus_id"], bus.get("route"))
        )
        child = cursor.fetchone()
        if not child:
            return jsonify({"success": False, "message": "Student is not assigned to this driver's bus"}), 400

        # Check if child is marked as Not Riding Today
        cursor.execute(
            "SELECT absence_id FROM child_bus_absence WHERE child_id = %s AND absence_date = CURDATE() AND status = 'Not Riding Today'",
            (child_id,)
        )
        if cursor.fetchone() and boarding_status == "Boarded":
            return jsonify({
                "success": False,
                "message": "Child is marked as not riding today."
            }), 400

        cursor.execute("SELECT trip_id FROM driver_trips WHERE driver_id = %s AND status = 'Active' ORDER BY trip_id DESC LIMIT 1", (driver_id,))
        trip = cursor.fetchone()
        trip_id = trip["trip_id"] if trip else None

        cursor.execute("SELECT attendance_id FROM student_boarding WHERE child_id = %s AND attendance_date = CURDATE()", (child_id,))
        existing = cursor.fetchone()

        if existing:
            if boarding_status == "Boarded":
                cursor.execute(
                    """
                    UPDATE student_boarding
                    SET boarding_status = %s,
                        boarding_time = CURTIME(),
                        driver_id = %s,
                        bus_id = %s,
                        trip_id = %s
                    WHERE attendance_id = %s
                    """,
                    (boarding_status, driver_id, bus["bus_id"], trip_id, existing["attendance_id"])
                )
            else:
                cursor.execute(
                    """
                    UPDATE student_boarding
                    SET boarding_status = %s,
                        boarding_time = NULL,
                        driver_id = %s,
                        bus_id = %s,
                        trip_id = %s
                    WHERE attendance_id = %s
                    """,
                    (boarding_status, driver_id, bus["bus_id"], trip_id, existing["attendance_id"])
                )
        else:
            if boarding_status == "Boarded":
                cursor.execute(
                    """
                    INSERT INTO student_boarding
                    (child_id, bus_id, driver_id, trip_id, attendance_date, boarding_status, boarding_time, stop_id)
                    VALUES (%s, %s, %s, %s, CURDATE(), %s, CURTIME(), %s)
                    """,
                    (child_id, bus["bus_id"], driver_id, trip_id, boarding_status, child["pickup_stop_id"])
                )
            else:
                cursor.execute(
                    """
                    INSERT INTO student_boarding
                    (child_id, bus_id, driver_id, trip_id, attendance_date, boarding_status, boarding_time, stop_id)
                    VALUES (%s, %s, %s, %s, CURDATE(), %s, NULL, %s)
                    """,
                    (child_id, bus["bus_id"], driver_id, trip_id, boarding_status, child["pickup_stop_id"])
                )
        conn.commit()

        cursor.execute("SELECT boarding_status, boarding_time FROM student_boarding WHERE child_id = %s AND attendance_date = CURDATE()", (child_id,))
        rec = cursor.fetchone()
        serialized_rec = serialize_row(rec) if rec else {}

        return jsonify({
            "success": True,
            "message": f"Student marked as {boarding_status}",
            "child_id": child_id,
            "boarding_status": boarding_status,
            "boarding_time": serialized_rec.get("boarding_time")
        }), 200

    except mysql.connector.Error as e:
        if conn: conn.rollback()
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()






    print("")
    print("============================================")
    print("        ROUTESAFE FLASK BACKEND")
    print("============================================")
    print("Database: routesafe_db")
    print("Server: http://127.0.0.1:5000")
    print("")
    print("MAIN APIs")
    print("--------------------------------------------")
    print("Login:")
    print("POST /login")
    print("")
    print("Registration:")
    print("POST /register")
    print("")
    print("Parent Requests:")
    print("GET  /admin/parent-requests")
    print("GET  /admin/parent-requests/count")
    print("PUT  /admin/parents/<id>/approve")
    print("PUT  /admin/parents/<id>/reject")
    print("")
    print("Child Management:")
    print("GET  /admin/children")
    print("POST /admin/children/link")
    print("POST /admin/children")
    print("PUT  /admin/children/<id>/assign")
    print("GET  /admin/children/details")
    print("")
    print("Parent Dashboard:")
    print("GET /parent/<id>/dashboard")
    print("GET /parent/<id>/children")
    print("")
    print("Live Tracking:")
    print("POST /driver/<id>/location")
    print("GET  /driver/<id>/location")
    print("GET  /parent/<parent_id>/child/<child_id>/location")
    print("============================================")
    print("")


# ============================================================
# ADMIN EMERGENCIES
# ============================================================

@app.route("/admin/emergencies", methods=["GET"])
def get_admin_emergencies():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                e.emergency_id,
                e.driver_id,
                u.full_name AS driver_name,
                u.phone AS driver_phone,
                e.message,
                e.status,
                e.created_at
            FROM driver_emergencies e
            LEFT JOIN users u ON e.driver_id = u.user_id
            ORDER BY e.emergency_id DESC
            """
)
        
        emergencies = cursor.fetchall() or []

        return jsonify({
            "success": True,
            "emergencies": [
                serialize_row(item)
                for item in emergencies
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


# ============================================================
# PENDING DRIVER REQUESTS
# ============================================================

@app.route("/admin/driver-requests", methods=["GET"])
def get_pending_driver_requests():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT
                user_id AS driver_id,
                full_name,
                email,
                phone,
                role,
                status,
                created_at
            FROM users
            WHERE role = 'Driver'
              AND status = 'PENDING'
            ORDER BY user_id DESC
            """
)
        
        requests = cursor.fetchall() or []

        return jsonify({
            "success": True,
            "requests": [
                serialize_row(req)
                for req in requests
            ]
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


@app.route("/admin/driver-requests/count", methods=["GET"])
def get_pending_driver_count():

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT COUNT(*) AS count
            FROM users
            WHERE role = 'Driver'
              AND status = 'PENDING'
            """
        )
        result = cursor.fetchone()

        return jsonify({
            "success": True,
            "count": int(result["count"]) if result else 0
        }), 200

    except mysql.connector.Error as e:

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


@app.route("/admin/drivers/<int:driver_id>/approve", methods=["PUT"])
def approve_driver(driver_id):

    conn = None
    cursor = None

    try:

        data = request.get_json(silent=True) or {}
        bus_id = data.get("bus_id")
        

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        # Get driver full name
        cursor.execute(
            """
            SELECT full_name
            FROM users
            WHERE user_id = %s AND role = 'Driver'
            """,
            (driver_id,)
        )
        driver = cursor.fetchone()

        if not driver:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        # Approve driver
        cursor.execute(
            """
            UPDATE users
            SET status = 'APPROVED'
            WHERE user_id = %s AND role = 'Driver'
            """,
            (driver_id,)
        )

        # Assign bus if provided
        if bus_id:

            cursor.execute(
                """
                UPDATE buses
                SET driver_name = %s, driver_id = %s
                WHERE bus_id = %s
                """,
                (driver["full_name"], driver_id, bus_id)
        )
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Driver approved and bus assigned successfully",
            "driver_id": driver_id,
            "bus_id": bus_id
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()


@app.route("/admin/drivers/<int:driver_id>/reject", methods=["PUT"])
def reject_driver(driver_id):

    conn = None
    cursor = None

    try:

        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        

        data = request.get_json(silent=True) or {}
        reason = str(data.get("rejection_reason") or data.get("reason") or "").strip()
        cursor.execute(
            """
            UPDATE users
            SET status = 'REJECTED', rejection_reason = %s
            WHERE user_id = %s AND role = 'Driver'
            """,
            (reason if reason else None, driver_id)
        )

        if cursor.rowcount == 0:

            return jsonify({
                "success": False,
                "message": "Driver not found"
            }), 404

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Driver registration rejected",
            "driver_id": driver_id
        }), 200

    except mysql.connector.Error as e:

        if conn:
            conn.rollback()

        return jsonify({
            "success": False,
            "message": f"Database error: {e}"
        }), 500

    finally:

        if cursor:
            cursor.close()

        if conn:
            conn.close()



# ============================================================
# ADMIN MODULE EXTENSION ENDPOINTS
# ============================================================

@app.route("/admin/dashboard/metrics", methods=["GET"])
def get_admin_dashboard_metrics():
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT COUNT(*) AS total FROM buses")
        total_buses = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM users WHERE role = 'Driver' AND status = 'APPROVED'")
        total_drivers = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM users WHERE role = 'Parent' AND status = 'APPROVED'")
        total_parents = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM parent_children")
        total_students = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM driver_trips WHERE status = 'Active'")
        active_trips = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM users WHERE role = 'Driver' AND status = 'PENDING'")
        pending_drivers = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM parent_registration_requests WHERE status = 'PENDING'")
        pending_parents = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM routes")
        total_routes = cursor.fetchone()["total"]

        cursor.execute("SELECT COUNT(*) AS total FROM driver_emergencies WHERE status = 'Pending'")
        pending_emergencies = cursor.fetchone()["total"]

        return jsonify({
            "success": True,
            "metrics": {
                "total_buses": total_buses,
                "total_drivers": total_drivers,
                "total_parents": total_parents,
                "total_students": total_students,
                "active_trips": active_trips,
                "pending_drivers": pending_drivers,
                "pending_parents": pending_parents,
                "total_routes": total_routes,
                "pending_emergencies": pending_emergencies
            },
            "total_buses": total_buses,
            "total_drivers": total_drivers,
            "total_parents": total_parents,
            "total_students": total_students,
            "active_trips": active_trips,
            "pending_drivers": pending_drivers,
            "pending_parents": pending_parents,
            "total_routes": total_routes,
            "pending_emergencies": pending_emergencies
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/routes", methods=["POST"])
def add_admin_route():
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        route_name = str(data.get("route_name") or "").strip()

        if not route_name:
            return jsonify({"success": False, "message": "Route name is required"}), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("INSERT INTO routes (route_name) VALUES (%s)", (route_name,))
        route_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Route added successfully",
            "route_id": route_id,
            "route_name": route_name
        }), 201
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/routes/<int:route_id>", methods=["PUT"])
def update_admin_route(route_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        route_name = str(data.get("route_name") or "").strip()

        if not route_name:
            return jsonify({"success": False, "message": "Route name is required"}), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("UPDATE routes SET route_name = %s WHERE route_id = %s", (route_name, route_id))
        conn.commit()

        return jsonify({"success": True, "message": "Route updated successfully"}), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/routes/<int:route_id>", methods=["DELETE"])
def delete_admin_route(route_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("DELETE FROM routes WHERE route_id = %s", (route_id,))
        conn.commit()

        return jsonify({"success": True, "message": "Route deleted successfully"}), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/routes/<int:route_id>/stops", methods=["POST"])
def add_admin_stop(route_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        stop_name = str(data.get("stop_name") or "").strip()
        stop_order = data.get("stop_order") or 1
        latitude = data.get("latitude")
        longitude = data.get("longitude")

        if not stop_name:
            return jsonify({"success": False, "message": "Stop name is required"}), 400

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            INSERT INTO pickup_stops (route_id, stop_name, stop_order, latitude, longitude)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (route_id, stop_name, stop_order, latitude, longitude)
        )
        stop_id = cursor.lastrowid
        conn.commit()

        return jsonify({
            "success": True,
            "message": "Stop added successfully",
            "stop_id": stop_id
        }), 201
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/stops/<int:stop_id>", methods=["PUT"])
def update_admin_stop(stop_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        stop_name = str(data.get("stop_name") or "").strip()
        stop_order = data.get("stop_order")
        
        latitude = data.get("latitude")
        
        longitude = data.get("longitude")
        

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            UPDATE pickup_stops
            SET stop_name = COALESCE(%s, stop_name),
                stop_order = COALESCE(%s, stop_order),
                latitude = COALESCE(%s, latitude),
                longitude = COALESCE(%s, longitude))
        
            WHERE stop_id = %s
            """,
            (stop_name if stop_name else None, stop_order, latitude, longitude, stop_id))
        conn.commit()

        return jsonify({"success": True, "message": "Stop updated successfully"}), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/stops/<int:stop_id>", methods=["DELETE"])
def delete_admin_stop(stop_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("DELETE FROM pickup_stops WHERE stop_id = %s", (stop_id,))
        conn.commit()

        return jsonify({"success": True, "message": "Stop deleted successfully"}), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/history", methods=["GET"])
def get_admin_history_logs():
    conn = None
    cursor = None
    try:
        history_type = request.args.get("type", "trips")
        
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        if history_type == "trips":
            cursor.execute(
                """
                SELECT t.trip_id, u.full_name AS driver_name, b.bus_number, b.route, t.start_time, t.end_time, t.status
                FROM driver_trips t
                LEFT JOIN users u ON t.driver_id = u.user_id
                LEFT JOIN buses b ON t.bus_id = b.bus_id
                ORDER BY t.trip_id DESC
                LIMIT 100
                """)
        
            logs = cursor.fetchall()
        elif history_type == "locations":
            cursor.execute(
                """
                SELECT dl.location_id, u.full_name AS driver_name, dl.latitude, dl.longitude, dl.updated_at
                FROM driver_locations dl
                LEFT JOIN users u ON dl.driver_id = u.user_id
                ORDER BY dl.updated_at DESC
                LIMIT 100
                """)
        
            logs = cursor.fetchall()
        elif history_type == "boarding":
            cursor.execute(
                """
                SELECT sb.attendance_id, pc.child_name, u.full_name AS parent_name, b.bus_number, sb.boarding_status, sb.boarding_time, sb.drop_off_status, sb.drop_off_time, sb.attendance_date
                FROM student_boarding sb
                JOIN parent_children pc ON sb.child_id = pc.child_id
                LEFT JOIN users u ON pc.parent_id = u.user_id
                LEFT JOIN buses b ON sb.bus_id = b.bus_id
                ORDER BY sb.attendance_id DESC
                LIMIT 100
                """)
        
            logs = cursor.fetchall()
        elif history_type == "emergencies":
            cursor.execute(
                """
                SELECT de.emergency_id, u.full_name AS driver_name, de.emergency_type, de.message, de.status, de.created_at, b.bus_number
                FROM driver_emergencies de
                LEFT JOIN users u ON de.driver_id = u.user_id
                LEFT JOIN buses b ON de.bus_id = b.bus_id
                ORDER BY de.emergency_id DESC
                LIMIT 100
                """)
        
            logs = cursor.fetchall()
        else: # assignments & logs
            cursor.execute("SELECT * FROM assignment_logs ORDER BY log_id DESC LIMIT 100")
        
            logs = cursor.fetchall()

        return jsonify({
            "success": True,
            "type": history_type,
            "logs": [serialize_row(l) for l in logs]
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()


@app.route("/admin/analytics", methods=["GET"])
def get_admin_analytics():
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT status, COUNT(*) AS count FROM driver_trips GROUP BY status")
        trips_breakdown = {r["status"]: r["count"] for r in cursor.fetchall()}
        active_trips = trips_breakdown.get("Active", 0)
        completed_trips = trips_breakdown.get("Completed", 0)

        cursor.execute("SELECT boarding_status, COUNT(*) AS count FROM student_boarding GROUP BY boarding_status")
        boarding_breakdown = {r["boarding_status"]: r["count"] for r in cursor.fetchall()}
        boarded_students = boarding_breakdown.get("Boarded", 0)
        not_boarded_students = boarding_breakdown.get("Not Boarded", 0)

        cursor.execute("SELECT status, COUNT(*) AS count FROM buses GROUP BY status")
        bus_breakdown = {r["status"]: r["count"] for r in cursor.fetchall()}
        cursor.execute("SELECT COUNT(*) AS total FROM buses")
        total_buses = cursor.fetchone()["total"]

        cursor.execute("SELECT status, COUNT(*) AS count FROM users WHERE role = 'Driver' GROUP BY status")
        driver_breakdown = {r["status"]: r["count"] for r in cursor.fetchall()}
        approved_drivers = driver_breakdown.get("APPROVED", 0)
        pending_drivers = driver_breakdown.get("PENDING", 0)

        cursor.execute("SELECT status, COUNT(*) AS count FROM users WHERE role = 'Parent' GROUP BY status")
        parent_breakdown = {r["status"]: r["count"] for r in cursor.fetchall()}
        approved_parents = parent_breakdown.get("APPROVED", 0)
        pending_parents = parent_breakdown.get("PENDING", 0)

        cursor.execute("SELECT COUNT(*) AS total FROM parent_children")
        total_students = cursor.fetchone()["total"]

        cursor.execute("SELECT COALESCE(emergency_type, 'Other') AS type, COUNT(*) AS count FROM driver_emergencies GROUP BY type")
        emergency_breakdown = {r["type"]: r["count"] for r in cursor.fetchall()}

        return jsonify({
            "success": True,
            "analytics": {
                "trips": trips_breakdown,
                "active_trips": active_trips,
                "completed_trips": completed_trips,
                "boarding": boarding_breakdown,
                "boarded_students": boarded_students,
                "not_boarded_students": not_boarded_students,
                "buses": bus_breakdown,
                "total_buses": total_buses,
                "active_buses": bus_breakdown.get("Active", total_buses),
                "drivers": driver_breakdown,
                "total_drivers": approved_drivers + pending_drivers,
                "approved_drivers": approved_drivers,
                "pending_drivers": pending_drivers,
                "parents": parent_breakdown,
                "total_parents": approved_parents + pending_parents,
                "approved_parents": approved_parents,
                "pending_parents": pending_parents,
                "total_students": total_students,
                "emergencies": emergency_breakdown
            }
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
# ============================================================
# SCHOOL SETTINGS ENDPOINTS
# ============================================================

@app.route("/school-settings", methods=["GET"])
@app.route("/admin/school-settings", methods=["GET"])
def get_school_settings_route():
    school = get_current_school_settings()
    return jsonify({
        "success": True,
        "school": school
    }), 200


@app.route("/school-settings", methods=["PUT", "POST"])
@app.route("/admin/school-settings", methods=["PUT", "POST"])
def update_school_settings_route():
    data = request.get_json(silent=True) or {}
    school_name = str(data.get("school_name") or data.get("name") or "").strip()
    address = str(data.get("address") or "").strip()
    
    try:
        latitude = float(data.get("latitude"))
        longitude = float(data.get("longitude"))
    except (ValueError, TypeError):
        return jsonify({"success": False, "message": "Valid numerical latitude and longitude values are required"}), 400

    if not school_name:
        return jsonify({"success": False, "message": "School name is required"}), 400
    if not address:
        return jsonify({"success": False, "message": "Address is required"}), 400

    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        ensure_school_table()
        cursor.execute("SELECT id FROM school_settings ORDER BY id ASC LIMIT 1")
        existing = cursor.fetchone()
        if existing:
            cursor.execute("""
                UPDATE school_settings
                SET school_name = %s, address = %s, latitude = %s, longitude = %s
                WHERE id = %s
            """, (school_name, address, latitude, longitude, existing["id"]))
        else:
            cursor.execute("""
                INSERT INTO school_settings (id, school_name, address, latitude, longitude)
                VALUES (1, %s, %s, %s, %s)
            """, (school_name, address, latitude, longitude))
        conn.commit()
        
        updated_school = get_current_school_settings()
        return jsonify({
            "success": True,
            "message": "School settings saved successfully in MySQL",
            "school": updated_school
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

# ============================================================
# PARENT NOTIFICATIONS ENDPOINT
# ============================================================

@app.route("/parent/<int:parent_id>/notifications", methods=["GET"])
def get_parent_notifications(parent_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT child_id, child_name, bus_id, pickup_stop_id
            FROM parent_children
            WHERE parent_id = %s
            """,
            (parent_id,)
        )
        children = cursor.fetchall()
        if not children:
            return jsonify({"success": True, "notifications": []}), 200

        child_ids = [c["child_id"] for c in children]
        child_map = {c["child_id"]: c["child_name"] for c in children}
        bus_ids = [c["bus_id"] for c in children if c["bus_id"]]

        notifications = []

        # 1. Boarding Notifications
        if child_ids:
            format_strings = ','.join(['%s'] * len(child_ids))
            cursor.execute(
                f"""
                SELECT sb.attendance_id, sb.child_id, sb.boarding_status, sb.boarding_time, sb.attendance_date, b.bus_number
                FROM student_boarding sb
                LEFT JOIN buses b ON sb.bus_id = b.bus_id
                WHERE sb.child_id IN ({format_strings})
                ORDER BY sb.attendance_id DESC
                LIMIT 50
                """,
                tuple(child_ids)
            )
            boarding_rows = cursor.fetchall()
            for r in boarding_rows:
                cname = child_map.get(r["child_id"], "Student")
                bnum = r.get("bus_number") or "School Bus"
                bstatus = r.get("boarding_status") or "Boarded"
                btime = serialize_row(r).get("boarding_time") or "Today"
                notifications.append({
                    "id": f"boarding_{r['attendance_id']}",
                    "title": f"Child {bstatus}",
                    "subtitle": f"{cname} was marked '{bstatus}' on {bnum}",
                    "time": str(btime),
                    "type": "boarding",
                    "date": str(r.get("attendance_date") or "")
                })

        # 2. Trip Notifications
        if bus_ids:
            format_strings_bus = ','.join(['%s'] * len(bus_ids))
            cursor.execute(
                f"""
                SELECT dt.trip_id, dt.bus_id, dt.start_time, dt.end_time, dt.status, b.bus_number, b.route
                FROM driver_trips dt
                LEFT JOIN buses b ON dt.bus_id = b.bus_id
                WHERE dt.bus_id IN ({format_strings_bus})
                ORDER BY dt.trip_id DESC
                LIMIT 30
                """,
                tuple(bus_ids)
            )
            trip_rows = cursor.fetchall()
            for t in trip_rows:
                bnum = t.get("bus_number") or "School Bus"
                route_name = t.get("route") or "School Route"
                status = t.get("status") or "Completed"
                t_time = serialize_row(t).get("start_time") or "Recently"
                if status.lower() in ["active", "on route", "started"]:
                    ntitle = "Trip Started"
                    nsub = f"Bus {bnum} has started its trip on route {route_name}"
                else:
                    ntitle = "Trip Completed"
                    nsub = f"Bus {bnum} completed trip on route {route_name}"

                notifications.append({
                    "id": f"trip_{t['trip_id']}",
                    "title": ntitle,
                    "subtitle": nsub,
                    "time": str(t_time),
                    "type": "trip",
                    "date": ""
                })

        # 3. Pickup Stop Notifications
        for c in children:
            if c.get("pickup_stop_id"):
                cursor.execute(
                    """
                    SELECT ps.stop_name, r.route_name
                    FROM pickup_stops ps
                    LEFT JOIN routes r ON ps.route_id = r.route_id
                    WHERE ps.stop_id = %s
                    """,
                    (c["pickup_stop_id"],)
                )
                stop_row = cursor.fetchone()
                if stop_row:
                    notifications.append({
                        "id": f"stop_{c['child_id']}",
                        "title": "Pickup Stop Active",
                        "subtitle": f"{c['child_name']} assigned to pickup stop: {stop_row['stop_name']} ({stop_row.get('route_name') or 'Route'})",
                        "time": "Active",
                        "type": "system",
                        "date": ""
                    })

        return jsonify({
            "success": True,
            "notifications": notifications
        }), 200

    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
