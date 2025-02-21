/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

NEW_CONNECTION;
-- Create table in autocommit mode

@EXPECT RESULT_SET 'AUTOCOMMIT',true
SHOW VARIABLE AUTOCOMMIT;
@EXPECT RESULT_SET 'READONLY',false
SHOW VARIABLE READONLY;

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='valid_ddl_autocommit';

CREATE TABLE VALID_DDL_AUTOCOMMIT (ID BIGINT PRIMARY KEY, BAR VARCHAR(100));

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='valid_ddl_autocommit';


NEW_CONNECTION;
-- Try to create a table with an invalid SQL statement

@EXPECT RESULT_SET 'AUTOCOMMIT',true
SHOW VARIABLE AUTOCOMMIT;
@EXPECT RESULT_SET 'READONLY',false
SHOW VARIABLE READONLY;

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='invalid_ddl_autocommit';

@EXPECT EXCEPTION INVALID_ARGUMENT
CREATE TABLE INVALID_DDL_AUTOCOMMIT (ID BIGINT PRIMARY KEY, BAZ VARCHAR(100), MISSING_DATA_TYPE_COL);

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='invalid_ddl_autocommit';


NEW_CONNECTION;
-- Try to create a new table in a DDL_BATCH

-- Check that the table is not present
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='valid_single_ddl_in_ddl_batch';

-- Change to DDL batch mode
SET AUTOCOMMIT = FALSE;
START BATCH DDL;

-- Execute the create table statement, but do not commit yet
CREATE TABLE VALID_SINGLE_DDL_IN_DDL_BATCH (ID BIGINT PRIMARY KEY, BAR VARCHAR(100));

NEW_CONNECTION;
-- Transaction has not been committed, so the table should not be present
-- We do this in a new transaction, as selects are not allowed in a DDL_BATCH
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='valid_single_ddl_in_ddl_batch';

-- Change to DDL batch mode again
SET AUTOCOMMIT = FALSE;
START BATCH DDL;

-- Execute the create table statement and do a commit
CREATE TABLE VALID_SINGLE_DDL_IN_DDL_BATCH (ID BIGINT PRIMARY KEY, BAR VARCHAR(100));
RUN BATCH;

-- Go back to AUTOCOMMIT mode and check that the table was created
SET AUTOCOMMIT = TRUE;

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='valid_single_ddl_in_ddl_batch';


NEW_CONNECTION;
-- Create two tables in one batch

-- First ensure that the tables do not exist
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='valid_multiple_ddl_in_ddl_batch_1' OR TABLE_NAME='valid_multiple_ddl_in_ddl_batch_2';

-- Change to DDL batch mode
SET AUTOCOMMIT = FALSE;
START BATCH DDL;

-- Create two tables
CREATE TABLE VALID_MULTIPLE_DDL_IN_DDL_BATCH_1 (ID BIGINT PRIMARY KEY, BAR VARCHAR(100));
CREATE TABLE VALID_MULTIPLE_DDL_IN_DDL_BATCH_2 (ID BIGINT PRIMARY KEY, BAR VARCHAR(100));
-- Run the batch
RUN BATCH;

-- Switch to autocommit and verify that both tables exist
SET AUTOCOMMIT = TRUE;

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 2 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='valid_multiple_ddl_in_ddl_batch_1' OR TABLE_NAME='valid_multiple_ddl_in_ddl_batch_2';


NEW_CONNECTION;
/*
 * Do a test that shows that a DDL batch might only execute some of the statements,
 * for example if data in a table prevents a unique index from being created.
 */
SET AUTOCOMMIT = FALSE;
START BATCH DDL;

CREATE TABLE TEST1 (ID BIGINT PRIMARY KEY, NAME VARCHAR(100));
CREATE TABLE TEST2 (ID BIGINT PRIMARY KEY, NAME VARCHAR(100));
RUN BATCH;

SET AUTOCOMMIT = TRUE;

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 2 AS "EXPECTED"
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME='test1' OR TABLE_NAME='test2';

-- Fill the second table with some data that will prevent us from creating a unique index on
-- the name column.
INSERT INTO TEST2 (ID, NAME) VALUES (1, 'TEST');
INSERT INTO TEST2 (ID, NAME) VALUES (2, 'TEST');

-- Ensure the indices that we are to create do not exist
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.INDEXES
WHERE (TABLE_NAME='test1' AND INDEX_NAME='idx_test1')
   OR (TABLE_NAME='test2' AND INDEX_NAME='idx_test2');

-- Try to create two unique indices in one batch
SET AUTOCOMMIT = FALSE;
START BATCH DDL;

CREATE UNIQUE INDEX IDX_TEST1 ON TEST1 (NAME);
CREATE UNIQUE INDEX IDX_TEST2 ON TEST2 (NAME);

@EXPECT EXCEPTION FAILED_PRECONDITION
RUN BATCH;

SET AUTOCOMMIT = TRUE;

-- Ensure that IDX_TEST1 was created and IDX_TEST2 was not.
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1 AS "EXPECTED"
FROM INFORMATION_SCHEMA.INDEXES
WHERE TABLE_NAME='test1' AND INDEX_NAME='idx_test1';

@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 0 AS "EXPECTED"
FROM INFORMATION_SCHEMA.INDEXES
WHERE TABLE_NAME='test2' AND INDEX_NAME='idx_test2';

NEW_CONNECTION;
/* Verify that empty DDL batches are accepted. */
START BATCH DDL;
RUN BATCH;

START BATCH DDL;
ABORT BATCH;
