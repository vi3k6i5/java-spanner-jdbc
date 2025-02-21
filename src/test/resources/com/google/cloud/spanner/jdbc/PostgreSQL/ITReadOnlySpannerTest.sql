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

-- Test a couple of count queries to ensure the presence of the data
@EXPECT RESULT_SET 'READONLY',true
SHOW VARIABLE READONLY;

-- Check initial contents.
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1000 AS "EXPECTED" FROM NUMBERS;

-- Check initial contents.
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 168 AS "EXPECTED" FROM PRIME_NUMBERS;

-- Assert that there is a read timestamp
@EXPECT RESULT_SET 'READ_TIMESTAMP'
SHOW VARIABLE READ_TIMESTAMP;

NEW_CONNECTION;
-- Test two selects in one temporary transaction
@EXPECT RESULT_SET 'READONLY',true
SHOW VARIABLE READONLY;

BEGIN;

@EXPECT RESULT_SET 'number',1
SELECT NUMBER
FROM NUMBERS
WHERE NUMBER=1;

@PUT 'READ_TIMESTAMP1'
SHOW VARIABLE READ_TIMESTAMP;

@EXPECT RESULT_SET 'prime_number',13
SELECT PRIME_NUMBER
FROM PRIME_NUMBERS
WHERE PRIME_NUMBER=13;

@PUT 'READ_TIMESTAMP2'
SHOW VARIABLE READ_TIMESTAMP;

COMMIT;

NEW_CONNECTION;
--TimestampBound.ofExactStaleness(1, TimeUnit.MILLISECONDS),

SET READ_ONLY_STALENESS = 'EXACT_STALENESS 1ms';

-- Check SELECT with EXACT_STALENESS
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1000 AS "EXPECTED" FROM NUMBERS;

@EXPECT RESULT_SET 'READ_TIMESTAMP'
SHOW VARIABLE READ_TIMESTAMP;

-- Check SELECT with EXACT_STALENESS
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 168 AS "EXPECTED" FROM PRIME_NUMBERS;

@EXPECT RESULT_SET 'READ_TIMESTAMP'
SHOW VARIABLE READ_TIMESTAMP;


NEW_CONNECTION;
--TimestampBound.ofMaxStaleness(100, TimeUnit.MILLISECONDS)

SET READ_ONLY_STALENESS = 'MAX_STALENESS 100ms';

-- Check SELECT with MAX_STALENESS
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1000 AS "EXPECTED" FROM NUMBERS;

@EXPECT RESULT_SET 'READ_TIMESTAMP'
SHOW VARIABLE READ_TIMESTAMP;

-- Check SELECT with MAX_STALENESS
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 168 AS "EXPECTED" FROM PRIME_NUMBERS;

@EXPECT RESULT_SET 'READ_TIMESTAMP'
SHOW VARIABLE READ_TIMESTAMP;


NEW_CONNECTION;
--TimestampBound.strong()

SET READ_ONLY_STALENESS = 'STRONG';

-- Check SELECT with STRONG
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1000 AS "EXPECTED" FROM NUMBERS;

@EXPECT RESULT_SET 'READ_TIMESTAMP'
SHOW VARIABLE READ_TIMESTAMP;

-- Check SELECT with STRONG
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 168 AS "EXPECTED" FROM PRIME_NUMBERS;

@EXPECT RESULT_SET 'READ_TIMESTAMP'
SHOW VARIABLE READ_TIMESTAMP;

NEW_CONNECTION;
--TimestampBound.ofMaxStaleness(100, TimeUnit.MILLISECONDS)
SET AUTOCOMMIT = FALSE;

@EXPECT EXCEPTION FAILED_PRECONDITION
SET READ_ONLY_STALENESS = 'MAX_STALENESS 100ms';


NEW_CONNECTION;
--TimestampBound.strong()
SET AUTOCOMMIT = FALSE;

SET READ_ONLY_STALENESS = 'STRONG';

-- Check SELECT with STRONG in a transaction.
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 1000 AS "EXPECTED" FROM NUMBERS;

@PUT 'READ_TIMESTAMP1'
SHOW VARIABLE READ_TIMESTAMP;

-- Check SELECT with STRONG in a transaction.
@EXPECT RESULT_SET
SELECT COUNT(*) AS "ACTUAL", 168 AS "EXPECTED" FROM PRIME_NUMBERS;

@PUT 'READ_TIMESTAMP2'
SHOW VARIABLE READ_TIMESTAMP;
