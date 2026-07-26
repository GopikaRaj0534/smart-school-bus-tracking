from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector

app = Flask(__name__)
CORS(app)

db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="",      # Change if your MySQL has a password
    database="routesafe_db"
)

@app.route("/")
def home():
    return "RouteSafe API Running"

@app.route("/login", methods=["POST"])
def login():

    data = request.get_json()

    email = data["email"]
    password = data["password"]
    role = data["role"]

    cursor = db.cursor(dictionary=True)

    cursor.execute(
        """
        SELECT * FROM users
        WHERE email=%s
        AND password=%s
        AND role=%s
        """,
        (email, password, role),
    )

    user = cursor.fetchone()

    if user:
        return jsonify({
            "success": True,
            "user": user
        })

    return jsonify({
        "success": False,
        "message": "Invalid Login"
    })

if __name__ == "__main__":
    app.run(debug=True)