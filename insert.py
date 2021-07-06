#!/usr/bin/python3

import os
import psycopg2
from datetime import datetime

from configparser import ConfigParser

def config(filename='database.ini', section='postgresql'):
    # create a parser
    parser = ConfigParser()
    # read config file
    parser.read(filename)
    # get section, default to postgresql
    db = {}
    if parser.has_section(section):
        params = parser.items(section)
        for param in params:
            db[param[0]] = param[1]
    else:
        raise Exception('Section {0} not found in the {1} file'.format(section, filename))
    return db

def drop_view(view_name):
    sql = "DROP VIEW IF EXISTS " + view_name + ";"

    conn = None

    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql)
        # get the powervs_id back
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()

def create_view(view_name, source_table):

    sql="CREATE VIEW " + view_name + " AS (SELECT * FROM " + source_table + ");"
    conn = None

    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql)
        # get the powervs_id back
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()

def create_table(table_name):

    sql="CREATE TABLE " + table_name + " AS (SELECT * FROM all_vms) with no data;"
    conn = None

    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql)
        # get the powervs_id back
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()

def insert_data(table,IBMCLOUD_ID,IBMCLOUD_NAME,PVS_NAME,VM_ID,VM_NAME,VM_AGE,VM_OS,VM_PROCESSOR,VM_MEMORY):

    sql = "INSERT INTO " + table + " (IBM_CLOUD_ID,IBM_CLOUD_NAME,PVS_NAME,VM_ID,VM_NAME,VM_AGE,VM_OS,VM_PROCESSOR,VM_MEMORY) \
    VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING VM_NAME;"
    conn = None
    powervs_id = None
    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        # execute the INSERT statement
        cur.execute(sql, (IBMCLOUD_ID,IBMCLOUD_NAME,PVS_NAME,VM_ID,VM_NAME,VM_AGE,VM_OS,VM_PROCESSOR,VM_MEMORY,))
        # get the powervs_id back
        powervs_id = cur.fetchone()[0]
        # commit the changes to the database
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
    return powervs_id


def copy_data(table,csv_file):
    conn = None
    powervs_id = None
    try:
        # read database configuration
        params = config()
        # connect to the PostgreSQL database
        conn = psycopg2.connect(**params)
        # create a new cursor
        cur = conn.cursor()
        with open(csv_file, 'r') as csv:
            cur.copy_from(csv,table,sep=',')
        conn.commit()
        # close communication with the database
        cur.close()
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
    return powervs_id


if __name__ == '__main__':

    if os.path.exists("all.csv"):
        #clean_table()
        today = datetime.today().strftime('%Y%m%d_%H%M%S')
        new_table = "all_vms_" + today
        create_table(new_table)
        copy_data(new_table,"all.csv")

        # with open("all.csv") as f:
        #     content = f.readlines()
        #     pvs_data = [x.strip() for x in content]

        #     for data in pvs_data:
        #         # ds: data splited
        #         ds = data.split(",")
        #         insert_data(new_table,ds[0],ds[1],ds[3],ds[2],ds[4],ds[5],ds[6],ds[7],ds[8])
        drop_view("pvsdata_all_vms")
        create_view("pvsdata_all_vms",new_table)
    else:
        print ("ERROR: could not locate the required .csv file")
        exit(1)
