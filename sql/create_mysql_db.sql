/*
    Version for MySQL
*/
DROP TABLE IF EXISTS FILES;
DROP TABLE IF EXISTS CANDIDATES;

/*
    "Main" table to store data
*/
CREATE TABLE CANDIDATES (
    CANDIDATE_ID integer AUTO_INCREMENT,
    FIRST_NAME VARCHAR(64) NOT NULL,
    LAST_NAME VARCHAR(64) NOT NULL,
    EMAIL VARCHAR(100) NOT NULL UNIQUE,
    LETTER_ID VARCHAR(64) PRIMARY KEY,
    INDEX(CANDIDATE_ID)
);

/*
    Table with files
*/
CREATE TABLE FILES (
    LETTER_ID VARCHAR(64) PRIMARY KEY,
    LETTER_CONTENT BLOB,
    FOREIGN KEY(LETTER_ID) REFERENCES CANDIDATES(LETTER_ID)
);
