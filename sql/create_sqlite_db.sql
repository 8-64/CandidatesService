/*
    Version for SQLite dialect
*/
DROP TABLE IF EXISTS CANDIDATES;
DROP TABLE IF EXISTS FILES;

/*
    Table with files
*/
CREATE TABLE FILES (
    LETTER_ID VARCHAR(64) PRIMARY KEY,
    LETTER_CONTENT BLOB
);

/*
    "Main" table to store data
*/
CREATE TABLE CANDIDATES (
    CANDIDATE_ID integer PRIMARY KEY AUTOINCREMENT,
    FIRST_NAME VARCHAR(64) NOT NULL,
    LAST_NAME VARCHAR(64) NOT NULL,
    EMAIL VARCHAR(100) NOT NULL UNIQUE,
    LETTER_ID VARCHAR(64),
    FOREIGN KEY(LETTER_ID) REFERENCES FILES(LETTER_ID)
);
