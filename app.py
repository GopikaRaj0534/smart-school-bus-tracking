import os
import sqlite3
from pathlib import Path

from flask import Flask, jsonify, request
from flask_cors import CORS

try:
    import mysql.connector  # type: ignore
except ImportError:  # pragma: no cover
    mysql = None  # type: ignore

app = Flask(__name__)
CORS(app)

DB_PATH = Path(__file__).with_name("routesafe.db")


def get_db_connection():
    host = os.getenv("MYSQL_HOST", "127.0.0.1")
    user = os.getenv("MYSQL_USER", "root")
    password = os.getenv("MYSQL_PASSWORD", "")
    database = os.getenv("MYSQL_DATABASE", "routesafe_db")

    if mysql is None:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn, "sqlite"

    try:
        conn = mysql.connector.connect(
            host=host,
            user=user,
            password=password,
            autocommit=True,
        )
        cursor = conn.cursor()
        cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{database}`")
        cursor.execute(f"USE `{database}`")
        return conn, "mysql"
    except Exception:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn, "sqlite"


def init_db():
    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor()
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    user_id INT AUTO_INCREMENT PRIMARY KEY,
                    full_name VARCHAR(255) NOT NULL,
                    email VARCHAR(255) NOT NULL UNIQUE,
                    phone VARCHAR(50) NOT NULL,
                    password VARCHAR(255) NOT NULL,
                    role VARCHAR(50) NOT NULL
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS buses (
                    bus_id INT AUTO_INCREMENT PRIMARY KEY,
                    bus_number VARCHAR(100) NOT NULL,
                    route VARCHAR(255) NOT NULL,
                    driver_name VARCHAR(255),
                    capacity INT,
                    status VARCHAR(50) NOT NULL DEFAULT 'Active'
                )
                """
            )
            conn.commit()
        else:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    full_name TEXT NOT NULL,
                    email TEXT NOT NULL UNIQUE,
                    phone TEXT NOT NULL,
                    password TEXT NOT NULL,
                    role TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS buses (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    bus_number TEXT NOT NULL,
                    route TEXT NOT NULL,
                    driver_name TEXT,
                    capacity INTEGER,
                    status TEXT NOT NULL DEFAULT 'Active'
                )
                """
            )
            conn.commit()
    finally:
        conn.close()


init_db()


@app.route("/")
def home():
    return jsonify({"status": "ok", "message": "RouteSafe API Running"})


@app.route("/register", methods=["POST"])
def register():
    data = request.get_json(silent=True) or {}
    full_name = (data.get("full_name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    phone = (data.get("phone") or "").strip()
    password = data.get("password") or ""
    role = (data.get("role") or "Parent").strip()

    if not all([full_name, email, phone, password, role]):
        return jsonify({
            "success": False,
            "message": "Please provide all required registration details"
        }), 400

    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT user_id FROM users WHERE email = %s", (email,))
            existing = cursor.fetchone()
            if existing:
                return jsonify({
                    "success": False,
                    "message": "An account with this email already exists"
                }), 409

            cursor.execute(
                """
                INSERT INTO users (full_name, email, phone, password, role)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (full_name, email, phone, password, role),
            )
            conn.commit()
        else:
            existing = conn.execute(
                "SELECT id FROM users WHERE email = ?",
                (email,),
            ).fetchone()
            if existing:
                return jsonify({
                    "success": False,
                    "message": "An account with this email already exists"
                }), 409

            conn.execute(
                """
                INSERT INTO users (full_name, email, phone, password, role)
                VALUES (?, ?, ?, ?, ?)
                """,
                (full_name, email, phone, password, role),
            )
            conn.commit()
    except Exception as exc:  # pragma: no cover
        return jsonify({
            "success": False,
            "message": f"Database error: {exc}"
        }), 500
    finally:
        conn.close()

    return jsonify({
        "success": True,
        "message": "Registration successful",
        "full_name": full_name,
        "role": role,
    })


@app.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    role = (data.get("role") or "Parent").strip()

    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT full_name, email, role
                FROM users
                WHERE email = %s AND password = %s AND role = %s
                """,
                (email, password, role),
            )
            user = cursor.fetchone()
        else:
            user = conn.execute(
                """
                SELECT full_name, email, role
                FROM users
                WHERE email = ? AND password = ? AND role = ?
                """,
                (email, password, role),
            ).fetchone()
            if user:
                user = dict(user)

        if user:
            return jsonify({
                "success": True,
                "message": "Login successful",
                "full_name": user["full_name"],
                "email": user["email"],
                "role": user["role"],
            })
    finally:
        conn.close()

    return jsonify({
        "success": False,
        "message": "Invalid login credentials"
    }), 401


@app.route("/buses", methods=["GET"])
def get_buses():
    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor(dictionary=True)
            cursor.execute(
                """
                SELECT bus_id, bus_number, route, driver_name, capacity, status
                FROM buses
                ORDER BY bus_id DESC
                """
            )
            buses = cursor.fetchall()
        else:
            rows = conn.execute(
                """
                SELECT id AS bus_id, bus_number, route, driver_name, capacity, status
                FROM buses
                ORDER BY id DESC
                """
            ).fetchall()
            buses = [dict(row) for row in rows]

        return jsonify({
            "success": True,
            "message": "Buses loaded",
            "buses": buses,
        })
    finally:
        conn.close()


@app.route("/buses", methods=["POST"])
def add_bus():
    data = request.get_json(silent=True) or {}
    bus_number = (data.get("bus_number") or "").strip()
    route = (data.get("route") or "").strip()
    driver_name = (data.get("driver_name") or "").strip()
    capacity = data.get("capacity")
    status = (data.get("status") or "Active").strip() or "Active"

    if not bus_number or not route:
        return jsonify({
            "success": False,
            "message": "Bus number and route are required"
        }), 400

    if capacity == "":
        capacity = None

    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO buses (bus_number, route, driver_name, capacity, status)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (bus_number, route, driver_name or None, capacity, status),
            )
            conn.commit()
            bus_id = cursor.lastrowid
        else:
            cursor = conn.execute(
                """
                INSERT INTO buses (bus_number, route, driver_name, capacity, status)
                VALUES (?, ?, ?, ?, ?)
                """,
                (bus_number, route, driver_name or None, capacity, status),
            )
            conn.commit()
            bus_id = cursor.lastrowid

        return jsonify({
            "success": True,
            "message": "Bus added successfully",
            "bus_id": bus_id,
            "bus_number": bus_number,
            "route": route,
            "driver_name": driver_name,
            "capacity": capacity,
            "status": status,
        })
    except Exception as exc:  # pragma: no cover
        return jsonify({
            "success": False,
            "message": f"Database error: {exc}"
        }), 500
    finally:
        conn.close()


@app.route("/buses/<int:bus_id>", methods=["PUT"])
def update_bus(bus_id):
    data = request.get_json(silent=True) or {}
    bus_number = (data.get("bus_number") or "").strip()
    route = (data.get("route") or "").strip()
    driver_name = (data.get("driver_name") or "").strip()
    capacity = data.get("capacity")
    status = (data.get("status") or "Active").strip() or "Active"

    if capacity == "":
        capacity = None

    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor()
            cursor.execute(
                """
                UPDATE buses
                SET bus_number = %s, route = %s, driver_name = %s, capacity = %s, status = %s
                WHERE id = %s
                """,
                (bus_number, route, driver_name or None, capacity, status, bus_id),
            )
            conn.commit()
        else:
            conn.execute(
                """
                UPDATE buses
                SET bus_number = ?, route = ?, driver_name = ?, capacity = ?, status = ?
                WHERE id = ?
                """,
                (bus_number, route, driver_name or None, capacity, status, bus_id),
            )
            conn.commit()

        return jsonify({
            "success": True,
            "message": "Bus updated successfully",
        })
    except Exception as exc:  # pragma: no cover
        return jsonify({
            "success": False,
            "message": f"Database error: {exc}"
        }), 500
    finally:
        conn.close()


@app.route("/buses/<int:bus_id>", methods=["DELETE"])
def delete_bus(bus_id):
    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor()
            cursor.execute("DELETE FROM buses WHERE id = %s", (bus_id,))
            conn.commit()
        else:
            conn.execute("DELETE FROM buses WHERE id = ?", (bus_id,))
            conn.commit()

        return jsonify({
            "success": True,
            "message": "Bus deleted successfully",
        })
    except Exception as exc:  # pragma: no cover
        return jsonify({
            "success": False,
            "message": f"Database error: {exc}"
        }), 500
    finally:
        conn.close()


@app.route("/drivers/count", methods=["GET"])
def get_drivers_count():
    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT COUNT(*) as count FROM users WHERE role = %s", ("Driver",))
            result = cursor.fetchone()
        else:
            result = conn.execute(
                "SELECT COUNT(*) as count FROM users WHERE role = ?",
                ("Driver",)
            ).fetchone()
            if result:
                result = dict(result)

        count = result["count"] if result else 0
        return jsonify({
            "success": True,
            "count": count,
        })
    finally:
        conn.close()


@app.route("/parents/count", methods=["GET"])
def get_parents_count():
    conn, engine = get_db_connection()
    try:
        if engine == "mysql":
            cursor = conn.cursor(dictionary=True)
            cursor.execute("SELECT COUNT(*) as count FROM users WHERE role = %s", ("Parent",))
            result = cursor.fetchone()
        else:
            result = conn.execute(
                "SELECT COUNT(*) as count FROM users WHERE role = ?",
                ("Parent",)
            ).fetchone()
            if result:
                result = dict(result)

        count = result["count"] if result else 0
        return jsonify({
            "success": True,
            "count": count,
        })
    finally:
        conn.close()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)