import mysql.connector
import sqlite3
import os

def export_mysql_to_sqlite():
    m_conn = mysql.connector.connect(
        host='127.0.0.1',
        port=3306,
        user='root',
        password='',
        database='routesafe_db'
    )
    m_cur = m_conn.cursor(dictionary=True)
    m_cur.execute('SHOW TABLES')
    tables = [list(r.values())[0] for r in m_cur.fetchall()]
    print('MySQL Tables found:', tables)

    sqlite_db_file = 'routesafe.db'
    if os.path.exists(sqlite_db_file):
        try:
            os.remove(sqlite_db_file)
        except Exception:
            pass

    s_conn = sqlite3.connect(sqlite_db_file)
    s_cur = s_conn.cursor()

    for table in tables:
        m_cur.execute(f"DESCRIBE {table}")
        columns_info = m_cur.fetchall()
        
        col_defs = []
        for col in columns_info:
            c_name = col['Field']
            c_type = col['Type'].upper()
            
            if 'INT' in c_type:
                s_type = 'INTEGER'
            elif 'DOUBLE' in c_type or 'FLOAT' in c_type or 'DECIMAL' in c_type:
                s_type = 'REAL'
            else:
                s_type = 'TEXT'
                
            if col['Key'] == 'PRI':
                col_defs.append(f"{c_name} {s_type} PRIMARY KEY")
            else:
                col_defs.append(f"{c_name} {s_type}")

        create_sql = f"CREATE TABLE IF NOT EXISTS {table} ({', '.join(col_defs)});"
        s_cur.execute(create_sql)

        m_cur.execute(f"SELECT * FROM {table}")
        rows = m_cur.fetchall()
        if rows:
            cols = list(rows[0].keys())
            placeholders = ', '.join(['?'] * len(cols))
            col_names = ', '.join(cols)
            query = f"INSERT INTO {table} ({col_names}) VALUES ({placeholders})"
            data_to_insert = [tuple(str(r[c]) if r[c] is not None else None for c in cols) for r in rows]
            s_cur.executemany(query, data_to_insert)

    s_conn.commit()
    s_conn.close()
    m_conn.close()
    print("Export to routesafe.db completed successfully!")

if __name__ == '__main__':
    export_mysql_to_sqlite()
