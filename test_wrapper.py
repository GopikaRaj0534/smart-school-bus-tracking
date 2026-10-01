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

if __name__ == '__main__':
    wrapper = SQLiteConnectionWrapper('routesafe.db')
    cursor = wrapper.cursor(dictionary=True)
    cursor.execute('SELECT * FROM users WHERE email = %s', ('anju@gmail.com',))
    user = cursor.fetchone()
    print('SQLite Wrapper Output:', user)
    cursor.execute('SELECT * FROM buses')
    buses = cursor.fetchall()
    print('SQLite Wrapper Buses Count:', len(buses))
