import Foundation

/// Lightweight SQL / ksqlDB lexer. Tokens never overlap, so comment markers inside
/// strings and keywords inside quoted identifiers retain their original meaning.
public enum QuerySyntax {
    public enum Kind: String { case keyword, string, identifier, number, comment, function, parameter }
    public struct Token {
        public let range: NSRange
        public let kind: Kind
    }
    public static func language(forExtension ext: String) -> String? {
        switch ext.lowercased() {
        case "sql", "psql", "pgsql", "mysql", "ddl", "dml": return "SQL"
        case "ksql", "ksqldb": return "Kafka / ksqlDB"
        default: return nil
        }
    }
    private static let sql = Set("""
        SELECT FROM WHERE AND OR NOT AS DISTINCT ALL JOIN INNER LEFT RIGHT FULL OUTER CROSS ON USING
        GROUP BY HAVING ORDER ASC DESC LIMIT OFFSET FETCH FIRST NEXT ROW ROWS ONLY UNION INTERSECT EXCEPT
        INSERT INTO VALUES UPDATE SET DELETE MERGE WHEN MATCHED THEN CREATE ALTER DROP TRUNCATE TABLE
        VIEW INDEX DATABASE SCHEMA IF EXISTS REPLACE TEMP TEMPORARY WITH RECURSIVE MATERIALIZED
        PRIMARY KEY FOREIGN REFERENCES UNIQUE CHECK DEFAULT CONSTRAINT ADD COLUMN RENAME CASCADE
        BEGIN COMMIT ROLLBACK TRANSACTION GRANT REVOKE TO EXPLAIN ANALYZE CASE ELSE END IS NULL TRUE FALSE
        IN BETWEEN LIKE ILIKE ESCAPE EXISTS ANY SOME OVER PARTITION RANGE UNBOUNDED PRECEDING FOLLOWING
        CURRENT CURRENT_DATE CURRENT_TIME CURRENT_TIMESTAMP FILTER NULLS LAST RETURNING CONFLICT DO NOTHING
        INT INTEGER BIGINT SMALLINT TINYINT NUMERIC DECIMAL REAL DOUBLE PRECISION FLOAT BOOLEAN BOOL
        VARCHAR CHAR CHARACTER TEXT STRING DATE TIME TIMESTAMP INTERVAL JSON JSONB ARRAY MAP STRUCT
        CAST TRY_CAST EXTRACT AT ZONE UNION ALL WINDOW LATERAL UNNEST TOP USE SHOW DESCRIBE
        """.split(whereSeparator: \.isWhitespace).map(String.init))
    private static let kafka = Set("""
        STREAM STREAMS TABLES TOPIC TOPICS KAFKA_TOPIC VALUE_FORMAT KEY_FORMAT FORMAT PARTITIONS REPLICAS
        EMIT CHANGES FINAL WINDOW TUMBLING HOPPING SESSION SIZE ADVANCE RETENTION GRACE PERIOD WITHIN
        SECONDS SECOND MINUTES MINUTE HOURS HOUR DAYS DAY MILLISECONDS MILLISECOND
        ROWTIME ROWKEY KEY HEADERS HEADER TIMESTAMP_FORMAT TIMESTAMP TIMESTAMPTOSTRING
        PRINT FROM BEGINNING SHOW DESCRIBE EXTENDED QUERIES CONNECTORS CONNECTOR SOURCE SINK
        TERMINATE PAUSE RESUME EXPLAIN INSERT INTO DELETE TOPIC ASSERT SCHEMA ID VALUE_SCHEMA_ID
        KEY_SCHEMA_ID WRAP_SINGLE_VALUE UNWRAP_SINGLE_VALUE SET UNSET DEFINE LIST PROPERTIES
        EARLIEST LATEST AS_VALUE EXPLODE STRUCT MAP ARRAY
        """.split(whereSeparator: \.isWhitespace).map(String.init))
    // Named groups make classification independent of captures in quoted strings.
    private static let pattern = #"(?<comment>--[^\r\n]*|/\*[\s\S]*?(?:\*/|\z))|(?<string>'(?:''|[^'])*(?:'|\z)|\$\$[\s\S]*?(?:\$\$|\z)|\$(?<tag>[A-Za-z_][A-Za-z_0-9]*)\$[\s\S]*?(?:\$\k<tag>\$|\z))|(?<identifier>"(?:""|[^"])*(?:"|\z)|`(?:``|[^`])*(?:`|\z)|\[(?:\]\]|[^\]])*(?:\]|\z))|(?<parameter>(?<!:):[A-Za-z_][A-Za-z_0-9]*|\$[0-9]+|\?)|(?<number>(?<![\w$])(?:0x[0-9a-f]+|(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)(?![\w$]))|(?<word>\b[A-Za-z_][A-Za-z_0-9]*\b)"#
    private static let expression = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

    public static func tokens(in text: String, kafkaMode: Bool) -> [Token] {
        let ns = text as NSString
        var tokens: [Token] = []
        expression.enumerateMatches(in: text, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
            guard let match else { return }
            for kind in [Kind.comment, .string, .identifier, .parameter, .number] {
                let range = match.range(withName: kind.rawValue)
                if range.location != NSNotFound { tokens.append(Token(range: range, kind: kind)); return }
            }
            let range = match.range(withName: "word")
            guard range.location != NSNotFound else { return }
            let word = ns.substring(with: range).uppercased()
            if sql.contains(word) || (kafkaMode && kafka.contains(word)) {
                tokens.append(Token(range: range, kind: .keyword))
            } else {
                var end = NSMaxRange(range)
                while end < ns.length, let scalar = UnicodeScalar(ns.character(at: end)), CharacterSet.whitespacesAndNewlines.contains(scalar) { end += 1 }
                if end < ns.length && ns.character(at: end) == 40 { tokens.append(Token(range: range, kind: .function)) }
            }
        }
        return tokens
    }
}
