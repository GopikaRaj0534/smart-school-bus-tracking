import secrets
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
# DATABASE CONFIGURATION & RESILIENT FALLBACK WRAPPER
# ============================================================

import sqlite3

class SQLiteDictCursor:
    def __init__(self, conn):
        self.conn = conn
        self.cursor = conn.cursor()
        self.description = None
        self.lastrowid = None
        self.rowcount = 0

    def execute(self, query, params=None):
        sqlite_query = query.replace('%s', '?').replace('NOW()', "datetime('now')").replace('now()', "datetime('now')")
        if params is None:
            self.cursor.execute(sqlite_query)
        else:
            if isinstance(params, dict):
                self.cursor.execute(sqlite_query, params)
            else:
                self.cursor.execute(sqlite_query, tuple(params))
        self.description = self.cursor.description
        self.lastrowid = self.cursor.lastrowid
        self.rowcount = self.cursor.rowcount
        return self

    def fetchone(self):
        row = self.cursor.fetchone()
        if row is None:
            return None
        columns = [desc[0] for desc in self.description]
        return dict(zip(columns, row))

    def fetchall(self):
        rows = self.cursor.fetchall()
        if not rows:
            return []
        columns = [desc[0] for desc in self.description]
        return [dict(zip(columns, row)) for row in rows]

    def close(self):
        self.cursor.close()

class SQLiteConnectionWrapper:
    def __init__(self, db_path='routesafe.db'):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.conn.create_function("CURDATE", 0, lambda: datetime.now().strftime("%Y-%m-%d"))
        self.conn.create_function("curdate", 0, lambda: datetime.now().strftime("%Y-%m-%d"))
        self.conn.create_function("NOW", 0, lambda: datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        self.conn.create_function("now", 0, lambda: datetime.now().strftime("%Y-%m-%d %H:%M:%S"))

    def cursor(self, dictionary=True, buffered=True):
        return SQLiteDictCursor(self.conn)

    def commit(self):
        self.conn.commit()

    def rollback(self):
        self.conn.rollback()

    def close(self):
        self.conn.close()

    def is_connected(self):
        return True


def get_db_config():
    raw_host = os.environ.get("DB_HOST", "localhost").strip()
    clean_host = raw_host.replace(" ", "")
    return {
        "host": clean_host if clean_host else "localhost",
        "port": int(os.environ.get("DB_PORT", "3306")),
        "user": os.environ.get("MYSQL_USER", os.environ.get("DB_USER", "root")),
        "password": os.environ.get("MYSQL_PASSWORD", os.environ.get("DB_PASSWORD", "")),
        "database": os.environ.get("MYSQL_DATABASE", os.environ.get("DB_NAME", "routesafe_db"))
    }


def get_db():
    config = get_db_config()
    # 1. Try configured MySQL host
    try:
        return mysql.connector.connect(**config)
    except Exception as e:
        print(f"[DATABASE NOTICE] Primary DB connection to {config.get('host')}:{config.get('port')} failed: {e}")

    # 2. Try local MySQL (localhost / 127.0.0.1)
    if config.get("host") not in ("localhost", "127.0.0.1"):
        try:
            local_config = {
                "host": "127.0.0.1",
                "port": 3306,
                "user": os.environ.get("MYSQL_USER", os.environ.get("DB_USER", "root")),
                "password": os.environ.get("MYSQL_PASSWORD", os.environ.get("DB_PASSWORD", "")),
                "database": os.environ.get("MYSQL_DATABASE", os.environ.get("DB_NAME", "routesafe_db"))
            }
            return mysql.connector.connect(**local_config)
        except Exception as local_err:
            print(f"[DATABASE NOTICE] Local MySQL connection failed: {local_err}")

    # 3. Fallback to resilient RouteSafe production SQLite fallback database
    print("[DATABASE NOTICE] Utilizing resilient RouteSafe production SQLite fallback database.")
    return SQLiteConnectionWrapper('routesafe.db')


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
            INSERT INTO users (full_name, email, phone, password, role, status, account_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (full_name, email, phone, hashed_password, role, account_status, account_status)
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

        if role in ["Parent", "Driver"]:

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
            WHERE LOWER(TRIM(email)) = LOWER(TRIM(%s)) OR LOWER(TRIM(full_name)) = LOWER(TRIM(%s))
            LIMIT 1
            """,
            (email, email)
        )

        user = cursor.fetchone()
        print(f"DEBUG LOGIN: input='{email}', found_user={user['email'] if user else None}")

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
                    "message": f"This account is registered as a {database_role}. Please select the {database_role} tab to log in."
                }), 400

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
                COALESCE(MAX(pr.request_id), u.user_id) AS request_id,
                u.user_id,
                u.full_name,
                u.email,
                u.phone,
                COALESCE(MAX(pr.child_name), MAX(pc.child_name), 'Not provided') AS child_name,
                COALESCE(MAX(pr.child_class), MAX(pc.class_name), 'Not provided') AS child_class,
                u.status,
                u.created_at
            FROM users u
            LEFT JOIN parent_registration_requests pr
                ON LOWER(TRIM(u.email)) = LOWER(TRIM(pr.email))
            LEFT JOIN parent_children pc
                ON u.user_id = pc.parent_id
            WHERE u.role = 'Parent'
              AND (UPPER(TRIM(u.status)) = 'PENDING' OR (pr.status IS NOT NULL AND UPPER(TRIM(pr.status)) = 'PENDING'))
            GROUP BY u.user_id, u.full_name, u.email, u.phone, u.status, u.created_at
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
@app.route("/buses/available", methods=["GET"])
@app.route("/admin/buses/available", methods=["GET"])
def get_buses():

    conn = None
    cursor = None

    try:
        available_only = request.args.get("available_only", "").lower() in ("true", "1", "yes") or "available" in request.path

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        query = """
            SELECT
                b.bus_id,
                b.bus_number,
                b.route,
                b.registration_number,
                b.driver_id,
                COALESCE(u.full_name, b.driver_name, 'Not Assigned') AS driver_name,
                b.status,
                CASE
                    WHEN (b.driver_id IS NULL OR b.driver_id = 0 OR u.user_id IS NULL)
                         AND (b.driver_name IS NULL OR TRIM(b.driver_name) = '' OR LOWER(TRIM(b.driver_name)) IN ('not assigned', 'unassigned'))
                    THEN 1 ELSE 0
                END AS is_available
            FROM buses b
            LEFT JOIN users u ON (b.driver_id = u.user_id OR (b.driver_name IS NOT NULL AND LOWER(TRIM(b.driver_name)) = LOWER(TRIM(u.full_name)))) AND u.role = 'Driver' AND u.status = 'APPROVED'
        """
        if available_only:
            query += """ WHERE ((b.driver_id IS NULL OR b.driver_id = 0 OR u.user_id IS NULL)
                           AND (b.driver_name IS NULL OR TRIM(b.driver_name) = '' OR LOWER(TRIM(b.driver_name)) IN ('not assigned', 'unassigned')))
                           AND (b.status IS NULL OR b.status = 'Active')"""
        query += " ORDER BY b.bus_id DESC"

        cursor.execute(query)
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

        # Resolve driver_id if driver_name matches an existing driver
        driver_id = None
        final_driver_name = driver_name if driver_name else 'Not Assigned'
        if driver_name and driver_name.lower() not in ("not assigned", "unassigned"):
            cursor.execute(
                "SELECT user_id FROM users WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(%s)) AND role = 'Driver' LIMIT 1",
                (driver_name,)
            )
            d_row = cursor.fetchone()
            if d_row:
                driver_id = d_row["user_id"]

        cursor.execute(
            """
            INSERT INTO buses (bus_number, route, driver_name, driver_id, status)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (bus_number, route, final_driver_name, driver_id, status)
        )
        conn.commit()

        new_bus_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "message": "Bus added successfully",
            "bus_id": new_bus_id,
            "bus": {
                "bus_id": new_bus_id,
                "bus_number": bus_number,
                "route": route,
                "driver_name": final_driver_name,
                "driver_id": driver_id,
                "status": status,
                "is_available": 1 if driver_id is None else 0
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
        cursor = conn.cursor(dictionary=True)

        driver_id = None
        final_driver_name = driver_name if driver_name else 'Not Assigned'
        if driver_name and driver_name.lower() not in ("not assigned", "unassigned"):
            cursor.execute(
                "SELECT user_id FROM users WHERE LOWER(TRIM(full_name)) = LOWER(TRIM(%s)) AND role = 'Driver' LIMIT 1",
                (driver_name,)
            )
            d_row = cursor.fetchone()
            if d_row:
                driver_id = d_row["user_id"]

        cursor.execute(
            """
            UPDATE buses
            SET bus_number = %s, route = %s, driver_name = %s, driver_id = %s, status = %s
            WHERE bus_id = %s
            """,
            (bus_number, route, final_driver_name, driver_id, status, bus_id)
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

        # 1. Unassign children assigned to this bus
        cursor.execute(
            """
            UPDATE parent_children
            SET bus_id = NULL
            WHERE bus_id = %s
            """,
            (bus_id,)
        )

        # 2. Delete boarding records for this bus
        cursor.execute(
            """
            DELETE FROM student_boarding
            WHERE bus_id = %s
            """,
            (bus_id,)
        )

        # 3. Delete bus record
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
                u.user_id,
                u.full_name,
                u.email,
                u.phone,
                u.role,
                u.status,
                COALESCE(d2fa.is_enabled, 0) AS two_factor_enabled
            FROM users u
            LEFT JOIN driver_2fa d2fa ON u.user_id = d2fa.user_id
            WHERE u.role = 'Driver'
            ORDER BY u.user_id DESC
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
                MAX(pc.child_name) AS child_name,
                MAX(pc.class_name) AS class_name,

                MAX(pc.bus_id) AS bus_id,
                MAX(b.bus_number) AS bus_number,
                COALESCE(MAX(u_driver.full_name), MAX(b.driver_name), 'Not Assigned') AS driver_name,
                MAX(u_driver.phone) AS driver_phone,
                MAX(b.status) AS bus_status,

                MAX(pc.route_id) AS route_id,
                COALESCE(MAX(r.route_name), MAX(b.route), 'Not Assigned') AS route_name,

                MAX(pc.pickup_stop_id) AS pickup_stop_id,
                MAX(ps.stop_name) AS stop_name,
                MAX(ps.stop_order) AS stop_order,
                MAX(ps.latitude) AS latitude,
                MAX(ps.longitude) AS longitude,

                IF(MAX(cba.absence_id) IS NOT NULL, 'SKIP', COALESCE(MAX(sb.boarding_status), 'Not Boarded')) AS boarding_status,
                IF(MAX(cba.absence_id) IS NOT NULL, TRUE, FALSE) AS is_absent,
                MAX(sb.boarding_time) AS boarding_time

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

            LEFT JOIN student_boarding sb
                ON pc.child_id = sb.child_id AND sb.attendance_date = CURDATE()

            LEFT JOIN child_bus_absence cba
                ON pc.child_id = cba.child_id AND cba.absence_date = CURDATE() AND cba.status != 'CANCELLED'

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

            if bus_id:
                try:
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

                        if driver_lat and driver_lng and stop_lat and stop_lng:
                            try:
                                import math
                                lat1, lon1 = float(driver_lat), float(driver_lng)
                                lat2, lon2 = float(stop_lat), float(stop_lng)
                                dlat = math.radians(lat2 - lat1)
                                dlon = math.radians(lon2 - lon1)
                                a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
                                c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
                                dist_km = 6371 * c
                                minutes = int((dist_km / 30.0) * 60)
                                if minutes < 1:
                                    minutes = 1
                                eta = f"{minutes} min"
                            except Exception:
                                eta = "ETA: Not available"
                        else:
                            eta = "ETA: Not available"
                    else:
                        trip_status = "Not Started"
                        eta = "ETA: Not available"
                except Exception as sub_e:
                    print("Error checking active trip in parent dashboard:", sub_e)
                    trip_status = "Not Started"
                    eta = "ETA: Not available"
            else:
                trip_status = "Not Started"
                eta = "ETA: Not available"

            child_dict["trip_status"] = trip_status
            child_dict["eta"] = eta
            processed_children.append(child_dict)

        return jsonify({
            "success": True,
            "parent": serialize_row(parent),
            "children": processed_children
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
                MAX(pc.child_name) AS child_name,
                MAX(pc.class_name) AS class_name,

                MAX(pc.bus_id) AS bus_id,
                MAX(b.bus_number) AS bus_number,
                COALESCE(MAX(u_driver.full_name), MAX(b.driver_name), 'Not Assigned') AS driver_name,
                MAX(u_driver.phone) AS driver_phone,

                COALESCE(MAX(pc.route_id), MAX(r.route_id)) AS route_id,
                COALESCE(MAX(r.route_name), MAX(b.route), 'Not Assigned') AS route_name,

                MAX(pc.pickup_stop_id) AS pickup_stop_id,
                MAX(ps.stop_name) AS stop_name,
                MAX(ps.latitude) AS latitude,
                MAX(ps.longitude) AS longitude,

                COALESCE(MAX(sb.boarding_status), 'Not Boarded') AS boarding_status,
                MAX(sb.boarding_time) AS boarding_time

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
                    COALESCE(MAX(sb.boarding_status), 'Not Boarded') AS boarding_status,
                    MAX(sb.boarding_time) AS boarding_time,
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
                GROUP BY
                    pc.child_id,
                    pc.child_name,
                    pc.class_name,
                    pc.bus_id,
                    b.bus_number,
                    pc.route_id,
                    r.route_name,
                    pc.pickup_stop_id,
                    ps.stop_name,
                    ps.latitude,
                    ps.longitude,
                    u_parent.full_name,
                    u_parent.phone,
                    u_parent.email
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


def send_2fa_otp_email(to_email, user_name, otp, purpose="LOGIN"):
    mail_server = os.environ.get("MAIL_SERVER", "smtp.gmail.com")
    mail_port = int(os.environ.get("MAIL_PORT", 587))
    mail_username = os.environ.get("MAIL_USERNAME", "")
    mail_password = os.environ.get("MAIL_PASSWORD", "")
    mail_from = os.environ.get("MAIL_FROM", mail_username or "noreply@routesafe.com")
    use_tls = os.environ.get("MAIL_USE_TLS", "true").lower() in ("true", "1", "yes")

    subject_map = {
        "LOGIN": "RouteSafe - Two-Factor Authentication Login Code",
        "ENABLE": "RouteSafe - Enable 2FA Verification Code",
        "DISABLE": "RouteSafe - Disable 2FA Verification Code",
        "RECOVERY": "RouteSafe - Account Recovery Verification Code"
    }
    subject = subject_map.get(purpose, "RouteSafe - 2FA Verification Code")
    p_name = purpose.replace('_', ' ')
    body = f"""Hello {user_name},

Your RouteSafe Two-Factor Authentication (2FA) verification code is:

    {otp}

This code will expire in 5 minutes.
Purpose: {p_name}

If you did not request this code, please secure your account immediately.
"""

    if not mail_username or not mail_password:
        print(f"[MAIL NOTICE] SMTP credentials not set. 2FA Code for {to_email} ({purpose}): {otp}")
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
        print(f"[MAIL ERROR] Failed to send 2FA OTP to {to_email}: {e}")
        return False, str(e)


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

def init_2fa_tables():
    try:
        conn = get_db()
        cursor = conn.cursor()
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS driver_2fa (
            user_id INT PRIMARY KEY,
            is_enabled TINYINT(1) DEFAULT 0,
            recovery_email VARCHAR(255) NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
        );
        """)
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS driver_2fa_otp (
            otp_id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            temp_token VARCHAR(255) NOT NULL,
            otp_hash VARCHAR(255) NOT NULL,
            purpose VARCHAR(50) DEFAULT 'LOGIN',
            attempts INT DEFAULT 0,
            verified TINYINT(1) DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            expires_at DATETIME NOT NULL,
            INDEX (temp_token),
            INDEX (user_id)
        );
        """)
        conn.commit()
        cursor.close()
        conn.close()
        print("2FA tables initialized successfully.")
    except Exception as e:
        print(f"Error initializing 2FA tables: {e}")

try:
    init_2fa_tables()
except Exception as e:
    print(f"2FA table init call error: {e}")



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
                IF(MAX(cba.absence_id) IS NOT NULL, 'SKIP', COALESCE(MAX(sb.boarding_status), 'Not Boarded')) AS boarding_status,
                IF(MAX(cba.absence_id) IS NOT NULL, TRUE, FALSE) AS is_absent,
                MAX(sb.boarding_time) AS boarding_time
            FROM parent_children pc
            LEFT JOIN users u ON pc.parent_id = u.user_id
            LEFT JOIN pickup_stops ps ON pc.pickup_stop_id = ps.stop_id
            LEFT JOIN routes r ON pc.route_id = r.route_id
            LEFT JOIN student_boarding sb ON pc.child_id = sb.child_id AND sb.attendance_date = CURDATE()
            LEFT JOIN child_bus_absence cba ON pc.child_id = cba.child_id AND cba.absence_date = CURDATE() AND cba.status != 'CANCELLED'
            WHERE pc.bus_id = %s OR (pc.bus_id IS NULL AND LOWER(TRIM(r.route_name)) = LOWER(TRIM(%s)))
            GROUP BY 
                pc.child_id,
                pc.child_name,
                pc.class_name,
                pc.parent_id,
                u.full_name,
                u.phone,
                u.email,
                pc.pickup_stop_id,
                ps.stop_name,
                ps.latitude,
                ps.longitude
            ORDER BY pc.child_name ASC
            """,
            (bus["bus_id"], bus.get("route"))
        )
        students = cursor.fetchall()
        serialized_students = [serialize_row(s) for s in students]
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
                SELECT bus_id, bus_number, driver_id, driver_name
                FROM buses
                WHERE bus_id = %s
                """,
                (bus_id,)
            )
            target_bus = cursor.fetchone()
            if not target_bus:
                return jsonify({
                    "success": False,
                    "message": "Selected bus does not exist"
                }), 404

            # Clear previous bus assignments for THIS driver to avoid duplicate active assignments
            cursor.execute(
                """
                UPDATE buses
                SET driver_name = 'Not Assigned', driver_id = NULL
                WHERE driver_id = %s OR LOWER(TRIM(driver_name)) = LOWER(TRIM(%s))
                """,
                (driver_id, driver["full_name"])
            )
            # Assign new bus to this driver
            cursor.execute(
                """
                UPDATE buses
                SET driver_name = %s, driver_id = %s
                WHERE bus_id = %s
                """,
                (driver["full_name"], driver_id, bus_id)
            )
        conn.commit()

        msg = "Driver approved and bus assigned successfully" if bus_id else "Driver approved successfully"
        return jsonify({
            "success": True,
            "message": msg,
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

        cursor.execute("SELECT boarding_status, COUNT(*) AS count FROM student_boarding GROUP BY boarding_status")
        boarding_breakdown = {r["boarding_status"]: r["count"] for r in cursor.fetchall()}

        cursor.execute("SELECT status, COUNT(*) AS count FROM buses GROUP BY status")
        bus_breakdown = {r["status"]: r["count"] for r in cursor.fetchall()}

        cursor.execute("SELECT COALESCE(emergency_type, 'Other') AS type, COUNT(*) AS count FROM driver_emergencies GROUP BY type")
        emergency_breakdown = {r["type"]: r["count"] for r in cursor.fetchall()}

        return jsonify({
            "success": True,
            "analytics": {
                "trips": trips_breakdown,
                "boarding": boarding_breakdown,
                "buses": bus_breakdown,
                "emergencies": emergency_breakdown
            }
        }), 200
    except mysql.connector.Error as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500
    finally:
        if cursor: cursor.close()
        if conn: conn.close()




# ============================================================
# DRIVER 2FA SECURITY ENDPOINTS
# ============================================================

@app.route("/api/driver/2fa/status", methods=["GET"])
def get_driver_2fa_status():
    driver_id = request.args.get("driver_id") or request.args.get("user_id")
    if not driver_id:
        return jsonify({"success": False, "message": "driver_id or user_id required"}), 400
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT is_enabled FROM driver_2fa WHERE user_id = %s LIMIT 1", (driver_id,))
        rec = cursor.fetchone()
        cursor.close()
        conn.close()
        is_enabled = bool(rec and rec.get("is_enabled") == 1)
        return jsonify({"success": True, "is_enabled": is_enabled}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/api/driver/2fa/verify-login", methods=["POST"])
def verify_driver_2fa_login():
    data = request.get_json(silent=True) or {}
    temp_token = str(data.get("temp_token") or "").strip()
    otp_input = str(data.get("otp") or "").strip()

    if not temp_token or not otp_input:
        return jsonify({"success": False, "message": "Verification token and code are required."}), 400

    if not otp_input.isdigit() or len(otp_input) != 6:
        return jsonify({"success": False, "message": "Code must be a 6-digit number."}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT * FROM driver_2fa_otp
            WHERE temp_token = %s AND purpose = 'LOGIN' AND verified = 0
            ORDER BY otp_id DESC LIMIT 1
            """,
            (temp_token,)
        )
        rec = cursor.fetchone()

        if not rec:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Invalid or expired 2FA session. Please log in again."}), 400

        # Check expiration
        expires_at = rec["expires_at"]
        if isinstance(expires_at, str):
            expires_at = datetime.strptime(expires_at, "%Y-%m-%d %H:%M:%S")
        if expires_at < datetime.now():
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "2FA code has expired. Please log in again to receive a new code."}), 400

        # Check max attempts
        attempts = int(rec.get("attempts") or 0)
        if attempts >= 5:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Maximum verification attempts exceeded. Please log in again."}), 400

        # Verify OTP hash
        if not check_password_hash(rec["otp_hash"], otp_input):
            cursor.execute("UPDATE driver_2fa_otp SET attempts = attempts + 1 WHERE otp_id = %s", (rec["otp_id"],))
            conn.commit()
            cursor.close()
            conn.close()
            remaining = 5 - (attempts + 1)
            return jsonify({"success": False, "message": f"Incorrect 2FA code. {remaining} attempt(s) remaining."}), 400

        # Mark OTP verified
        cursor.execute("UPDATE driver_2fa_otp SET verified = 1 WHERE otp_id = %s", (rec["otp_id"],))
        conn.commit()

        # Fetch full user details for response
        cursor.execute(
            "SELECT user_id, full_name, email, phone, role, status FROM users WHERE user_id = %s LIMIT 1",
            (rec["user_id"],)
        )
        user = cursor.fetchone()
        cursor.close()
        conn.close()

        if not user:
            return jsonify({"success": False, "message": "User account not found."}), 404

        user = serialize_row(user)
        print(f"[2FA SUCCESS] Driver {user['email']} completed 2FA login.")
        return jsonify({
            "success": True,
            "message": "2FA verification successful",
            "user": user
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": f"Database error: {e}"}), 500


@app.route("/api/driver/2fa/resend-otp", methods=["POST"])
def resend_driver_2fa_otp():
    data = request.get_json(silent=True) or {}
    temp_token = str(data.get("temp_token") or "").strip()
    user_id = data.get("user_id") or data.get("driver_id")
    purpose = str(data.get("purpose") or "LOGIN").strip().upper()

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        rec = None
        if temp_token:
            cursor.execute("SELECT * FROM driver_2fa_otp WHERE temp_token = %s ORDER BY otp_id DESC LIMIT 1", (temp_token,))
            rec = cursor.fetchone()
        elif user_id:
            cursor.execute("SELECT * FROM driver_2fa_otp WHERE user_id = %s AND purpose = %s ORDER BY otp_id DESC LIMIT 1", (user_id, purpose))
            rec = cursor.fetchone()

        if not rec:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "No active verification session found. Please try again."}), 400

        # Rate limiting check: at least 30 seconds since created_at
        created_at = rec["created_at"]
        if isinstance(created_at, str):
            created_at = datetime.strptime(created_at, "%Y-%m-%d %H:%M:%S")
        if (datetime.now() - created_at).total_seconds() < 30:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Please wait at least 30 seconds before requesting a new code."}), 429

        # Fetch user
        cursor.execute("SELECT user_id, full_name, email FROM users WHERE user_id = %s LIMIT 1", (rec["user_id"],))
        user = cursor.fetchone()

        if not user:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "User not found."}), 404

        otp_val = f"{random.randint(100000, 999999)}"
        otp_h = generate_password_hash(otp_val)
        new_token = secrets.token_hex(32)
        expires = datetime.now() + timedelta(minutes=5)

        cursor.execute(
            """
            INSERT INTO driver_2fa_otp (user_id, temp_token, otp_hash, purpose, expires_at)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (rec["user_id"], new_token, otp_h, rec["purpose"], expires)
        )
        conn.commit()
        cursor.close()
        conn.close()

        send_2fa_otp_email(user["email"], user["full_name"], otp_val, rec["purpose"])
        return jsonify({
            "success": True,
            "message": "A new verification code has been sent to your email.",
            "temp_token": new_token
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


def request_enable_2fa_with_id(driver_id):
    if not driver_id:
        return jsonify({"success": False, "message": "driver_id or user_id required"}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        cursor.execute(
            "SELECT user_id, full_name, email FROM users WHERE user_id = %s AND LOWER(TRIM(role)) = 'driver' LIMIT 1",
            (driver_id,)
        )
        driver = cursor.fetchone()
        if not driver:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": f"Driver with ID {driver_id} not found."}), 404

        otp_val = f"{random.randint(100000, 999999)}"
        otp_h = generate_password_hash(otp_val)
        temp_tok = secrets.token_hex(32)
        expires = datetime.now() + timedelta(minutes=5)

        cursor.execute(
            """
            INSERT INTO driver_2fa_otp (user_id, temp_token, otp_hash, purpose, expires_at)
            VALUES (%s, %s, %s, 'ENABLE', %s)
            """,
            (driver_id, temp_tok, otp_h, expires)
        )
        conn.commit()
        cursor.close()
        conn.close()

        send_2fa_otp_email(driver["email"], driver["full_name"], otp_val, "ENABLE")
        return jsonify({
            "success": True,
            "temp_token": temp_tok,
            "message": f"Verification code sent to {driver['email']}"
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/api/driver/2fa/request-enable", methods=["POST"])
@app.route("/api/driver/2fa/request-enable/", methods=["POST"])
def request_enable_2fa():
    data = request.get_json(silent=True) or {}
    driver_id = data.get("driver_id") or data.get("user_id")
    return request_enable_2fa_with_id(driver_id)


def verify_enable_2fa_with_params(driver_id, temp_token, otp_input):
    if not driver_id or not otp_input:
        return jsonify({"success": False, "message": "driver_id and 6-digit verification code are required"}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        rec = None
        if temp_token:
            cursor.execute(
                """
                SELECT * FROM driver_2fa_otp
                WHERE temp_token = %s AND purpose = 'ENABLE' AND verified = 0
                ORDER BY otp_id DESC LIMIT 1
                """,
                (temp_token,)
            )
            rec = cursor.fetchone()

        if not rec:
            cursor.execute(
                """
                SELECT * FROM driver_2fa_otp
                WHERE user_id = %s AND purpose = 'ENABLE' AND verified = 0
                ORDER BY otp_id DESC LIMIT 1
                """,
                (driver_id,)
            )
            rec = cursor.fetchone()

        if not rec:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "No pending 2FA setup request found."}), 400

        if not check_password_hash(rec["otp_hash"], otp_input):
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Incorrect verification code."}), 400

        # Mark verified
        cursor.execute("UPDATE driver_2fa_otp SET verified = 1 WHERE otp_id = %s", (rec["otp_id"],))

        # Enable in driver_2fa
        cursor.execute(
            """
            INSERT INTO driver_2fa (user_id, is_enabled)
            VALUES (%s, 1)
            ON DUPLICATE KEY UPDATE is_enabled = 1, updated_at = NOW()
            """,
            (driver_id,)
        )
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"success": True, "message": "Two-Factor Authentication has been enabled for your account!"}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/api/driver/2fa/verify-enable", methods=["POST"])
@app.route("/api/driver/2fa/verify-enable/", methods=["POST"])
def verify_enable_2fa():
    data = request.get_json(silent=True) or {}
    driver_id = data.get("driver_id") or data.get("user_id")
    temp_token = str(data.get("temp_token") or "").strip()
    otp_input = str(data.get("otp") or data.get("code") or "").strip()
    return verify_enable_2fa_with_params(driver_id, temp_token, otp_input)


@app.route("/api/driver/2fa/request-disable", methods=["POST"])
def request_disable_2fa():
    data = request.get_json(silent=True) or {}
    driver_id = data.get("driver_id") or data.get("user_id")
    password = str(data.get("password") or "").strip()

    if not driver_id or not password:
        return jsonify({"success": False, "message": "Driver ID and password are required to disable 2FA."}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT user_id, full_name, email, password FROM users WHERE user_id = %s AND role = 'Driver' LIMIT 1", (driver_id,))
        driver = cursor.fetchone()

        if not driver:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Driver account not found."}), 404

        # Validate password
        pwd_valid = False
        try:
            pwd_valid = check_password_hash(driver["password"], password)
        except Exception:
            pwd_valid = False
        if not pwd_valid and driver["password"] == password:
            pwd_valid = True

        if not pwd_valid:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Incorrect password. Cannot proceed with disabling 2FA."}), 401

        otp_val = f"{random.randint(100000, 999999)}"
        otp_h = generate_password_hash(otp_val)
        temp_tok = secrets.token_hex(32)
        expires = datetime.now() + timedelta(minutes=5)

        cursor.execute(
            """
            INSERT INTO driver_2fa_otp (user_id, temp_token, otp_hash, purpose, expires_at)
            VALUES (%s, %s, %s, 'DISABLE', %s)
            """,
            (driver_id, temp_tok, otp_h, expires)
        )
        conn.commit()
        cursor.close()
        conn.close()

        send_2fa_otp_email(driver["email"], driver["full_name"], otp_val, "DISABLE")
        return jsonify({
            "success": True,
            "temp_token": temp_tok,
            "message": f"Verification code sent to {driver['email']} to confirm disabling 2FA."
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/api/driver/2fa/verify-disable", methods=["POST"])
def verify_disable_2fa():
    data = request.get_json(silent=True) or {}
    driver_id = data.get("driver_id") or data.get("user_id")
    otp_input = str(data.get("otp") or "").strip()

    if not driver_id or not otp_input:
        return jsonify({"success": False, "message": "driver_id and code are required"}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT * FROM driver_2fa_otp
            WHERE user_id = %s AND purpose = 'DISABLE' AND verified = 0
            ORDER BY otp_id DESC LIMIT 1
            """,
            (driver_id,)
        )
        rec = cursor.fetchone()

        if not rec:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "No pending disable request found."}), 400

        if not check_password_hash(rec["otp_hash"], otp_input):
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Incorrect verification code."}), 400

        cursor.execute("UPDATE driver_2fa_otp SET verified = 1 WHERE otp_id = %s", (rec["otp_id"],))
        cursor.execute("UPDATE driver_2fa SET is_enabled = 0 WHERE user_id = %s", (driver_id,))
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({"success": True, "message": "Two-Factor Authentication has been disabled for your account."}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/api/driver/2fa/request-recovery", methods=["POST"])
def request_driver_2fa_recovery():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email") or "").strip().lower()
    phone = str(data.get("phone") or "").strip()

    if not email:
        return jsonify({"success": False, "message": "Registered Driver email is required for recovery."}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT user_id, full_name, email, phone FROM users WHERE LOWER(TRIM(email)) = %s AND role = 'Driver' LIMIT 1",
            (email,)
        )
        driver = cursor.fetchone()

        if not driver:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "No registered Driver account found matching that email."}), 404

        # Verify phone matching if provided
        if phone:
            db_phone = str(driver.get("phone") or "").strip()
            if db_phone and phone not in db_phone and db_phone not in phone:
                cursor.close()
                conn.close()
                return jsonify({"success": False, "message": "Phone number does not match registered account records."}), 400

        otp_val = f"{random.randint(100000, 999999)}"
        otp_h = generate_password_hash(otp_val)
        temp_tok = secrets.token_hex(32)
        expires = datetime.now() + timedelta(minutes=5)

        cursor.execute(
            """
            INSERT INTO driver_2fa_otp (user_id, temp_token, otp_hash, purpose, expires_at)
            VALUES (%s, %s, %s, 'RECOVERY', %s)
            """,
            (driver["user_id"], temp_tok, otp_h, expires)
        )
        conn.commit()
        cursor.close()
        conn.close()

        send_2fa_otp_email(driver["email"], driver["full_name"], otp_val, "RECOVERY")
        return jsonify({
            "success": True,
            "temp_token": temp_tok,
            "message": f"Account recovery verification code sent to your registered email ({driver['email']})."
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/api/driver/2fa/verify-recovery", methods=["POST"])
def verify_driver_2fa_recovery():
    data = request.get_json(silent=True) or {}
    temp_token = str(data.get("temp_token") or "").strip()
    otp_input = str(data.get("otp") or "").strip()

    if not temp_token or not otp_input:
        return jsonify({"success": False, "message": "Recovery token and code are required."}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            SELECT * FROM driver_2fa_otp
            WHERE temp_token = %s AND purpose = 'RECOVERY' AND verified = 0
            ORDER BY otp_id DESC LIMIT 1
            """,
            (temp_token,)
        )
        rec = cursor.fetchone()

        if not rec:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Invalid or expired recovery session."}), 400

        if not check_password_hash(rec["otp_hash"], otp_input):
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Incorrect recovery code."}), 400

        cursor.execute("UPDATE driver_2fa_otp SET verified = 1 WHERE otp_id = %s", (rec["otp_id"],))
        cursor.execute("UPDATE driver_2fa SET is_enabled = 0 WHERE user_id = %s", (rec["user_id"],))
        conn.commit()
        cursor.close()
        conn.close()

        return jsonify({
            "success": True,
            "message": "Identity verified successfully. 2FA has been reset for your Driver account. You can now log in using your password."
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/api/admin/driver/reset-2fa", methods=["POST"])
def admin_reset_driver_2fa():
    data = request.get_json(silent=True) or {}
    driver_id = data.get("driver_id")
    if not driver_id:
        return jsonify({"success": False, "message": "driver_id required"}), 400

    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT user_id, full_name FROM users WHERE user_id = %s AND role = 'Driver' LIMIT 1", (driver_id,))
        driver = cursor.fetchone()
        if not driver:
            cursor.close()
            conn.close()
            return jsonify({"success": False, "message": "Driver account not found."}), 404

        cursor.execute("UPDATE driver_2fa SET is_enabled = 0 WHERE user_id = %s", (driver_id,))
        conn.commit()
        cursor.close()
        conn.close()

        print(f"[ADMIN 2FA RESET] Admin reset 2FA for Driver ID {driver_id} ({driver['full_name']}).")
        return jsonify({
            "success": True,
            "message": f"2FA security has been successfully reset for driver '{driver['full_name']}'."
        }), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500



# ============================================================
# DRIVER 2FA ROUTE ALIASES FOR COMPATIBILITY
# ============================================================

@app.route("/driver/<int:driver_id>/2fa/status", methods=["GET"])
def get_driver_2fa_status_alias(driver_id):
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT is_enabled FROM driver_2fa WHERE user_id = %s LIMIT 1", (driver_id,))
        rec = cursor.fetchone()
        cursor.close()
        conn.close()
        is_enabled = bool(rec and rec.get("is_enabled") == 1)
        return jsonify({"success": True, "is_enabled": is_enabled}), 200
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500


@app.route("/driver/<int:driver_id>/2fa/request-enable", methods=["POST"])
@app.route("/driver/<int:driver_id>/2fa/enable", methods=["POST"])
@app.route("/api/driver/2fa/enable", methods=["POST"])
def request_enable_2fa_alias(driver_id=None):
    if not driver_id:
        data = request.get_json(silent=True) or {}
        driver_id = data.get("driver_id") or data.get("user_id")
    return request_enable_2fa_with_id(driver_id)


@app.route("/driver/<int:driver_id>/2fa/verify-enable", methods=["POST"])
@app.route("/driver/<int:driver_id>/2fa/verify", methods=["POST"])
@app.route("/api/driver/2fa/verify", methods=["POST"])
def verify_enable_2fa_alias(driver_id=None):
    data = request.get_json(silent=True) or {}
    did = driver_id or data.get("driver_id") or data.get("user_id")
    temp_token = str(data.get("temp_token") or "").strip()
    otp_input = str(data.get("otp") or data.get("code") or "").strip()
    return verify_enable_2fa_with_params(did, temp_token, otp_input)



@app.route("/debug/routes", methods=["GET"])
def debug_routes():
    routes = [f"{rule.endpoint}: {rule.rule} {list(rule.methods)}" for rule in app.url_map.iter_rules()]
    return jsonify({"routes": routes}), 200


# ============================================================
# PARENT ABSENCE & DYNAMIC ITINERARY ENDPOINTS
# ============================================================

@app.route("/parent/<int:parent_id>/child/<int:child_id>/absence", methods=["POST"])
def mark_child_absence(parent_id, child_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        absence_date = str(data.get("absence_date") or "").strip()
        if not absence_date:
            absence_date = datetime.now().strftime("%Y-%m-%d")

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            "SELECT route_id, pickup_stop_id FROM parent_children WHERE child_id = %s AND parent_id = %s LIMIT 1",
            (child_id, parent_id)
        )
        child_rec = cursor.fetchone()
        route_id = child_rec.get("route_id") if child_rec else None
        stop_id = child_rec.get("pickup_stop_id") if child_rec else None

        cursor.execute(
            """
            SELECT absence_id FROM child_bus_absence
            WHERE child_id = %s AND parent_id = %s AND absence_date = %s
            LIMIT 1
            """,
            (child_id, parent_id, absence_date)
        )
        existing = cursor.fetchone()
        if existing:
            cursor.execute(
                """
                UPDATE child_bus_absence
                SET status = 'Not Riding Today', updated_at = NOW()
                WHERE absence_id = %s
                """,
                (existing["absence_id"],)
            )
        else:
            cursor.execute(
                """
                INSERT INTO child_bus_absence (child_id, parent_id, route_id, stop_id, absence_date, status)
                VALUES (%s, %s, %s, %s, %s, 'Not Riding Today')
                """,
                (child_id, parent_id, route_id, stop_id, absence_date)
            )

        cursor.execute(
            """
            SELECT attendance_id FROM student_boarding
            WHERE child_id = %s AND attendance_date = %s
            LIMIT 1
            """,
            (child_id, absence_date)
        )
        sb_rec = cursor.fetchone()
        if sb_rec:
            cursor.execute(
                "UPDATE student_boarding SET boarding_time = NULL WHERE attendance_id = %s",
                (sb_rec["attendance_id"],)
            )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Child absence marked successfully. Bus driver notified to skip stop.",
            "is_absent": True,
            "status": "Not Riding Today"
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


@app.route("/parent/<int:parent_id>/child/<int:child_id>/absence/cancel", methods=["POST"])
def cancel_child_absence(parent_id, child_id):
    conn = None
    cursor = None
    try:
        data = request.get_json(silent=True) or {}
        absence_date = str(data.get("absence_date") or "").strip()
        if not absence_date:
            absence_date = datetime.now().strftime("%Y-%m-%d")

        conn = get_db()
        cursor = conn.cursor(dictionary=True)

        cursor.execute(
            """
            UPDATE child_bus_absence
            SET status = 'CANCELLED', updated_at = NOW()
            WHERE child_id = %s AND parent_id = %s AND absence_date = %s
            """,
            (child_id, parent_id, absence_date)
        )

        cursor.execute(
            """
            UPDATE student_boarding
            SET boarding_status = 'Not Boarded', boarding_time = NULL
            WHERE child_id = %s AND attendance_date = %s AND boarding_status = 'SKIP'
            """,
            (child_id, absence_date)
        )

        conn.commit()

        return jsonify({
            "success": True,
            "message": "Absence cancelled successfully. Child restored to bus itinerary.",
            "is_absent": False,
            "status": "Riding"
        }), 200

    except Exception as e:
        if conn:
            conn.rollback()
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


@app.route("/parent/<int:parent_id>/child/<int:child_id>/absence", methods=["GET"])
def get_child_absence(parent_id, child_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        today = datetime.now().strftime("%Y-%m-%d")

        cursor.execute(
            """
            SELECT absence_id, absence_date, status, created_at
            FROM child_bus_absence
            WHERE child_id = %s AND parent_id = %s AND absence_date = %s AND status != 'CANCELLED'
            LIMIT 1
            """,
            (child_id, parent_id, today)
        )
        absence = cursor.fetchone()
        is_absent = bool(absence is not None)

        return jsonify({
            "success": True,
            "is_absent": is_absent,
            "absence": serialize_row(absence) if absence else None
        }), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


@app.route("/driver/<int:driver_id>/itinerary", methods=["GET"])
def get_driver_itinerary(driver_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        today = datetime.now().strftime("%Y-%m-%d")

        cursor.execute(
            """
            SELECT b.bus_id, b.route, r.route_id
            FROM buses b
            LEFT JOIN users u ON (b.driver_id = u.user_id OR LOWER(TRIM(b.driver_name)) = LOWER(TRIM(u.full_name)))
            LEFT JOIN routes r ON LOWER(TRIM(b.route)) = LOWER(TRIM(r.route_name))
            WHERE u.user_id = %s AND u.role = 'Driver'
            LIMIT 1
            """,
            (driver_id,)
        )
        bus_rec = cursor.fetchone()

        if not bus_rec or not bus_rec.get("route_id"):
            return jsonify({
                "success": True,
                "stops": [],
                "skipped_stops_count": 0,
                "message": "No active route assigned to driver"
            }), 200

        route_id = bus_rec["route_id"]

        cursor.execute(
            """
            SELECT stop_id, stop_name, stop_order, latitude, longitude
            FROM pickup_stops
            WHERE route_id = %s
            ORDER BY stop_order ASC
            """,
            (route_id,)
        )
        stops = cursor.fetchall() or []

        cursor.execute(
            """
            SELECT cba.child_id, cba.stop_id
            FROM child_bus_absence cba
            WHERE cba.absence_date = %s AND cba.status != 'CANCELLED'
            """,
            (today,)
        )
        absent_records = cursor.fetchall() or []
        absent_child_ids = set(r["child_id"] for r in absent_records)

        cursor.execute(
            """
            SELECT pc.child_id, pc.pickup_stop_id, COALESCE(sb.boarding_status, 'Not Boarded') AS boarding_status
            FROM parent_children pc
            LEFT JOIN student_boarding sb ON pc.child_id = sb.child_id AND sb.attendance_date = %s
            WHERE pc.route_id = %s
            """,
            (today, route_id)
        )
        assigned_students = cursor.fetchall() or []

        processed_stops = []
        skipped_count = 0

        for stop in stops:
            stop_dict = serialize_row(stop)
            stop_id = stop_dict["stop_id"]

            stop_students = [s for s in assigned_students if s.get("pickup_stop_id") == stop_id]

            if stop_students and all(
                s["child_id"] in absent_child_ids or s.get("boarding_status") == "SKIP"
                for s in stop_students
            ):
                stop_dict["is_skipped"] = True
                stop_dict["status"] = "SKIPPED"
                skipped_count += 1
            else:
                stop_dict["is_skipped"] = False
                stop_dict["status"] = "ACTIVE"

            processed_stops.append(stop_dict)

        return jsonify({
            "success": True,
            "route_id": route_id,
            "stops": processed_stops,
            "skipped_stops_count": skipped_count
        }), 200

    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# ============================================================
# PARENT NOTIFICATIONS
# ============================================================

@app.route("/parent/<int:parent_id>/notifications", methods=["GET"])
def get_parent_notifications(parent_id):
    conn = None
    cursor = None
    try:
        conn = get_db()
        cursor = conn.cursor(dictionary=True)
        notifications = []

        # 1. Fetch boarding status logs for parent's children
        try:
            cursor.execute(
                """
                SELECT sb.child_id, pc.child_name, sb.boarding_status, sb.attendance_date, b.bus_number
                FROM student_boarding sb
                JOIN parent_children pc ON sb.child_id = pc.child_id
                LEFT JOIN buses b ON sb.bus_id = b.bus_id
                WHERE pc.parent_id = %s
                ORDER BY sb.attendance_date DESC
                LIMIT 10
                """,
                (parent_id,)
            )
            boarding_logs = cursor.fetchall() or []
            for b in boarding_logs:
                status = b.get("boarding_status", "Not Boarded")
                c_name = b.get("child_name", "Child")
                bus_num = b.get("bus_number") or "N/A"
                title = f"Boarding Update: {c_name}"
                msg = f"{c_name} status updated to {status} on Bus {bus_num}."
                notifications.append({
                    "id": f"board_{b.get('child_id')}_{b.get('attendance_date')}",
                    "title": title,
                    "message": msg,
                    "type": "boarding",
                    "timestamp": str(b.get("attendance_date") or "")
                })
        except Exception as e:
            print("Error fetching boarding notifications:", e)

        # 2. Fetch absence logs for parent's children
        try:
            cursor.execute(
                """
                SELECT cba.child_id, pc.child_name, cba.absence_date, cba.status, cba.created_at
                FROM child_bus_absence cba
                JOIN parent_children pc ON cba.child_id = pc.child_id
                WHERE pc.parent_id = %s
                ORDER BY cba.created_at DESC
                LIMIT 10
                """,
                (parent_id,)
            )
            absence_logs = cursor.fetchall() or []
            for a in absence_logs:
                c_name = a.get("child_name", "Child")
                a_date = a.get("absence_date", "")
                status = a.get("status", "SUBMITTED")
                notifications.append({
                    "id": f"abs_{a.get('child_id')}_{a.get('created_at')}",
                    "title": f"Absence Notification: {c_name}",
                    "message": f"Absence for {c_name} on {a_date} is {status}.",
                    "type": "absence",
                    "timestamp": str(a.get("created_at") or "")
                })
        except Exception as e:
            print("Error fetching absence notifications:", e)

        if not notifications:
            notifications.append({
                "id": "welcome_1",
                "title": "Welcome to RouteSafe",
                "message": "System alerts and child trip status updates will appear here.",
                "type": "system",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })

        return jsonify({
            "success": True,
            "notifications": notifications
        }), 200

    except Exception as e:
        print("PARENT NOTIFICATIONS ERROR:", e)
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()





# ============================================================
# GLOBAL JSON ERROR HANDLERS
# ============================================================

@app.errorhandler(404)
def handle_404(e):
    return jsonify({"success": False, "message": "Endpoint or resource not found (404)"}), 404

@app.errorhandler(405)
def handle_405(e):
    return jsonify({"success": False, "message": "HTTP Method not allowed (405)"}), 405

@app.errorhandler(500)
def handle_500(e):
    return jsonify({"success": False, "message": f"Server internal error: {e}"}), 500

@app.errorhandler(Exception)
def handle_exception(e):
    return jsonify({"success": False, "message": f"Unhandled server error: {str(e)}"}), 500

if __name__ == '__main__':
    port = int(os.environ.get("PORT", 5000))
    app.run(host='0.0.0.0', port=port, debug=False)
