/*
 * Copyright 2019 Google LLC
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

package com.google.cloud.spanner.jdbc.it;

import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.hamcrest.MatcherAssert.assertThat;

import com.google.cloud.spanner.Dialect;
import com.google.cloud.spanner.Mutation;
import com.google.cloud.spanner.ParallelIntegrationTest;
import com.google.cloud.spanner.jdbc.CloudSpannerJdbcConnection;
import com.google.cloud.spanner.jdbc.ITAbstractJdbcTest;
import com.google.cloud.spanner.jdbc.JdbcSqlScriptVerifier;
import com.google.common.collect.ImmutableMap;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.FixMethodOrder;
import org.junit.Test;
import org.junit.experimental.categories.Category;
import org.junit.runner.RunWith;
import org.junit.runners.MethodSorters;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameter;
import org.junit.runners.Parameterized.Parameters;

@Category(ParallelIntegrationTest.class)
@RunWith(Parameterized.class)
@FixMethodOrder(MethodSorters.NAME_ASCENDING)
public class ITJdbcReadWriteAutocommitTest extends ITAbstractJdbcTest {

  @Parameters(name = "Dialect = {0}")
  public static List<DialectTestParameter> data() {
    List<DialectTestParameter> params = new ArrayList<>();
    Map<String, String> googleStandardSqlScripts =
        ImmutableMap.of("TEST_READ_WRITE_AUTO_COMMIT", "ITReadWriteAutocommitSpannerTest.sql");
    Map<String, String> postgresScripts =
        ImmutableMap.of(
            "TEST_READ_WRITE_AUTO_COMMIT", "PostgreSQL/ITReadWriteAutocommitSpannerTest.sql");
    params.add(
        new DialectTestParameter(Dialect.GOOGLE_STANDARD_SQL, "", googleStandardSqlScripts, null));
    params.add(new DialectTestParameter(Dialect.POSTGRESQL, "", postgresScripts, null));
    return params;
  }

  @Parameter public DialectTestParameter dialect;

  @Override
  public Dialect getDialect() {
    return dialect.dialect;
  }

  @Override
  protected void appendConnectionUri(StringBuilder uri) {
    uri.append(";autocommit=true");
  }

  @Override
  public boolean doCreateDefaultTestTable() {
    return true;
  }

  @Test
  public void test01_SqlScript() throws Exception {
    JdbcSqlScriptVerifier verifier = new JdbcSqlScriptVerifier(new ITJdbcConnectionProvider());
    verifier.verifyStatementsInFile(
        dialect.executeQueriesFiles.get("TEST_READ_WRITE_AUTO_COMMIT"),
        ITAbstractJdbcTest.class,
        false);
  }

  @Test
  public void test02_WriteMutation() throws Exception {
    try (CloudSpannerJdbcConnection connection = createConnection(getDialect())) {
      connection.write(
          Mutation.newInsertBuilder("TEST").set("ID").to(9999L).set("NAME").to("FOO").build());
      java.sql.Statement statement = connection.createStatement();
      statement.execute("SHOW VARIABLE COMMIT_TIMESTAMP");
      try (java.sql.ResultSet rs = statement.getResultSet()) {
        assertThat(rs.next(), is(true));
        assertThat(rs.getTimestamp(1), is(notNullValue()));
      }
    }
  }
}
