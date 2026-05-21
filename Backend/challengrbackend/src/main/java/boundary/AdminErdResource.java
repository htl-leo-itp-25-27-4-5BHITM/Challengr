package boundary;

import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.PreparedStatement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.Locale;
import java.util.HashSet;


/**
 * Admin endpoint to visualize the DB schema as ERD.
 *
 * Note: This intentionally only exposes metadata (no table data).
 */
@Path("/api/admin/erd")
@Produces(MediaType.APPLICATION_JSON)
public class AdminErdResource {

    @Inject
    DataSource dataSource;

    public record ErdResponse(
            String catalog,
            String schema,
            List<Table> tables,
            List<Relation> relations
    ) {}

    public record Table(
            String name,
            List<Column> columns,
            List<String> primaryKey
    ) {}

    public record Column(
            String name,
            String type,
            boolean nullable
    ) {}

    public record Relation(
            String fromTable,
            List<String> fromColumns,
            String toTable,
            List<String> toColumns,
            String name
    ) {}

    public record TableDataResponse(
        String table,
        List<String> columns,
        List<Map<String, Object>> rows
    ) {}

    @GET
    public Response getErd() {
        try (Connection conn = dataSource.getConnection()) {
            DatabaseMetaData dbMeta = conn.getMetaData();

            String catalog = conn.getCatalog();
            String schema = safeSchema(conn);

            // Tables
            Map<String, Table> tablesByName = new LinkedHashMap<>();

            // Start with an explicit allow-list based on our JPA domain entities.
            // This avoids pulling in infrastructure tables (Keycloak, Flyway, etc.).
            Set<String> allowedTables = allowedDomainTables();
            try (ResultSet rs = dbMeta.getTables(catalog, schema, "%", new String[]{"TABLE"})) {
                while (rs.next()) {
                    String tableName = rs.getString("TABLE_NAME");
                    if (!isRelevantTable(tableName, allowedTables)) {
                        continue;
                    }
                    tablesByName.put(tableName, new Table(tableName, new ArrayList<>(), new ArrayList<>()));
                }
            }

            // Columns
            for (String table : tablesByName.keySet()) {
                List<Column> cols = new ArrayList<>();
                try (ResultSet rs = dbMeta.getColumns(catalog, schema, table, "%")) {
                    while (rs.next()) {
                        String colName = rs.getString("COLUMN_NAME");
                        String typeName = rs.getString("TYPE_NAME");
                        int nullable = rs.getInt("NULLABLE");
                        cols.add(new Column(colName, typeName, nullable != DatabaseMetaData.columnNoNulls));
                    }
                }

                List<String> pkCols = new ArrayList<>();
                try (ResultSet pk = dbMeta.getPrimaryKeys(catalog, schema, table)) {
                    // KEY_SEQ for ordering
                    Map<Short, String> ordered = new LinkedHashMap<>();
                    while (pk.next()) {
                        short seq = pk.getShort("KEY_SEQ");
                        ordered.put(seq, pk.getString("COLUMN_NAME"));
                    }
                    ordered.keySet().stream().sorted().forEach(k -> pkCols.add(ordered.get(k)));
                }

                tablesByName.put(table, new Table(table, cols, pkCols));
            }

            // Relations (group composite keys by FK_NAME)
            Map<String, RelationBuilder> relBuilders = new LinkedHashMap<>();
            for (String table : tablesByName.keySet()) {
                try (ResultSet fk = dbMeta.getImportedKeys(catalog, schema, table)) {
                    while (fk.next()) {
                        String fkName = fk.getString("FK_NAME");
                        if (fkName == null || fkName.isBlank()) {
                            fkName = table + "->" + fk.getString("PKTABLE_NAME");
                        }

                        String pkTable = fk.getString("PKTABLE_NAME");
                        String pkCol = fk.getString("PKCOLUMN_NAME");
                        String fkTable = fk.getString("FKTABLE_NAME");
                        String fkCol = fk.getString("FKCOLUMN_NAME");
                        short seq = fk.getShort("KEY_SEQ");

                        // Only keep relations where both tables survived filtering.
                        if (!tablesByName.containsKey(fkTable) || !tablesByName.containsKey(pkTable)) {
                            continue;
                        }

                        String key = fkTable + "|" + fkName;
                        RelationBuilder builder = relBuilders.get(key);
                        if (builder == null) {
                            builder = new RelationBuilder(fkTable, pkTable, fkName);
                            relBuilders.put(key, builder);
                        }
                        builder.add(seq, fkCol, pkCol);
                    }
                }
            }

            List<Relation> relations = relBuilders.values().stream().map(RelationBuilder::build).toList();

            // Add logical relations derived from JPA mappings / conventions.
            // This is important because some of our tables store references as plain strings
            // without actual FK constraints (e.g. friend_request.from_player_id).
            List<Relation> logicalRelations = buildLogicalRelations(tablesByName, relations);

            List<Relation> allRelations = new ArrayList<>(relations);
            allRelations.addAll(logicalRelations);
            ErdResponse response = new ErdResponse(catalog, schema, new ArrayList<>(tablesByName.values()), allRelations);
            return Response.ok(response).build();
        } catch (Exception e) {
            return Response.status(500).entity(Map.of(
                    "error", "erd_introspection_failed",
                    "message", e.getMessage() == null ? e.getClass().getName() : e.getMessage()
            )).build();
        }
    }

    @GET
    @Path("/table/{table}")
    public Response getTableData(@PathParam("table") String table,
                                 @QueryParam("limit") Integer limit) {
        String normalized = normalizeTableName(table);
        int safeLimit = (limit == null || limit <= 0) ? 50 : Math.min(limit, 200);

        Set<String> allowedTables = allowedDomainTables();
        if (!allowedTables.contains(normalized)) {
            return Response.status(403).entity(Map.of(
                    "error", "table_not_allowed",
                    "message", "Table is not available"
            )).build();
        }

        try (Connection conn = dataSource.getConnection()) {
            String catalog = conn.getCatalog();
            String schema = safeSchema(conn);
            DatabaseMetaData dbMeta = conn.getMetaData();

            // Resolve actual table name case from metadata
            String actualTable = null;
            try (ResultSet rs = dbMeta.getTables(catalog, schema, "%", new String[]{"TABLE"})) {
                while (rs.next()) {
                    String candidate = rs.getString("TABLE_NAME");
                    if (normalizeTableName(candidate).equals(normalized)) {
                        actualTable = candidate;
                        break;
                    }
                }
            }

            if (actualTable == null) {
                return Response.status(404).entity(Map.of(
                        "error", "table_not_found",
                        "message", "Table not found"
                )).build();
            }

            List<String> columns = new ArrayList<>();
            String quotedTable = quoteIdentifier(dbMeta, actualTable);
            String sqlTable = (schema != null && !schema.isBlank())
                    ? quoteIdentifier(dbMeta, schema) + "." + quotedTable
                    : quotedTable;
            String sql = "SELECT * FROM " + sqlTable + " LIMIT ?";
            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setInt(1, safeLimit);
                try (ResultSet rs = stmt.executeQuery()) {
                    ResultSetMetaData meta = rs.getMetaData();
                    int colCount = meta.getColumnCount();
                    for (int i = 1; i <= colCount; i++) {
                        columns.add(meta.getColumnLabel(i));
                    }

                    List<Map<String, Object>> rows = new ArrayList<>();
                    while (rs.next()) {
                        Map<String, Object> row = new LinkedHashMap<>();
                        for (int i = 1; i <= colCount; i++) {
                            row.put(columns.get(i - 1), rs.getObject(i));
                        }
                        rows.add(row);
                    }

                    return Response.ok(new TableDataResponse(actualTable, columns, rows)).build();
                }
            }
        } catch (Exception e) {
            return Response.status(500).entity(Map.of(
                    "error", "table_query_failed",
                    "message", e.getMessage() == null ? e.getClass().getName() : e.getMessage()
            )).build();
        }
    }

    private static String safeSchema(Connection conn) {
        try {
            String schema = conn.getSchema();
            return (schema != null && !schema.isBlank()) ? schema : null;
        } catch (Exception ignored) {
            return null;
        }
    }

    private static final class RelationBuilder {
        private final String fkTable;
        private final String pkTable;
        private final String name;
        private final Map<Short, String> fkCols = new LinkedHashMap<>();
        private final Map<Short, String> pkCols = new LinkedHashMap<>();

        private RelationBuilder(String fkTable, String pkTable, String name) {
            this.fkTable = fkTable;
            this.pkTable = pkTable;
            this.name = name;
        }

        private void add(short seq, String fkCol, String pkCol) {
            fkCols.put(seq, fkCol);
            pkCols.put(seq, pkCol);
        }

        private Relation build() {
            Set<Short> keys = new LinkedHashSet<>();
            keys.addAll(fkCols.keySet());
            keys.addAll(pkCols.keySet());

            List<String> from = new ArrayList<>();
            List<String> to = new ArrayList<>();
            keys.stream().sorted().forEach(k -> {
                from.add(fkCols.get(k));
                to.add(pkCols.get(k));
            });
            return new Relation(fkTable, from, pkTable, to, name);
        }
    }

    /**
     * We only want to show Challengr's domain tables in the dashboard, not infrastructure tables
     * like Keycloak. We primarily use an allow-list derived from our JPA entities.
     * As a fallback, we apply a small heuristic blacklist.
     */
    private static boolean isRelevantTable(String tableName, Set<String> allowedTables) {
        if (tableName == null) return false;

        String normalized = normalizeTableName(tableName);

        // Prefer allow-list if present
        if (allowedTables != null && !allowedTables.isEmpty()) {
            return allowedTables.contains(normalized);
        }

        String t = tableName.toLowerCase(Locale.ROOT);

        // Keycloak tables (typical prefixes)
        if (t.startsWith("keycloak")) return false;
        if (t.startsWith("kc_")) return false;
        if (t.startsWith("user_entity")) return false;

        // Other infra tables we don't want in the ERD view (extend as needed)
        if (t.startsWith("flyway_")) return false;
        if (t.startsWith("quartz")) return false;

        return true;
    }

    private static List<Relation> buildLogicalRelations(Map<String, Table> tablesByName, List<Relation> existing) {
        if (tablesByName == null || tablesByName.isEmpty()) return List.of();

        Set<String> existingKeys = new HashSet<>();
        for (Relation r : existing) {
            existingKeys.add(relKey(r.fromTable(), r.toTable(), r.fromColumns(), r.toColumns()));
        }

        List<Relation> out = new ArrayList<>();

        // --- 1) JPA ManyToOne relations (Battle, Challenges etc.) ---
        addJpaManyToOne(out, existingKeys, entity.Challenges.class, "challenges", "id", "challengeCategory", "category_id", "challenge_categories", "id", "category");

        addJpaManyToOne(out, existingKeys, entity.Battle.class, "battle", "id", "fromPlayer", "from_player_id", "player", "id", "fromPlayer");
        addJpaManyToOne(out, existingKeys, entity.Battle.class, "battle", "id", "toPlayer", "to_player_id", "player", "id", "toPlayer");
        addJpaManyToOne(out, existingKeys, entity.Battle.class, "battle", "id", "winner", "winner_id", "player", "id", "winner");
        addJpaManyToOne(out, existingKeys, entity.Battle.class, "battle", "id", "challenge", "challenge_id", "challenges", "id", "challenge");
        addJpaManyToOne(out, existingKeys, entity.Battle.class, "battle", "id", "category", "category_id", "challenge_categories", "id", "category");

        // --- 2) Convention-based logical relations (string ids) ---
        // FriendRequest(from_player_id/to_player_id) -> player.id
        addIfPresent(out, existingKeys, tablesByName,
                new Relation("friend_request", List.of("from_player_id"), "player", List.of("id"), "fromPlayer"));
        addIfPresent(out, existingKeys, tablesByName,
                new Relation("friend_request", List.of("to_player_id"), "player", List.of("id"), "toPlayer"));

        // Friendship(player_a_id/player_b_id) -> player.id
        addIfPresent(out, existingKeys, tablesByName,
                new Relation("friendship", List.of("player_a_id"), "player", List.of("id"), "playerA"));
        addIfPresent(out, existingKeys, tablesByName,
                new Relation("friendship", List.of("player_b_id"), "player", List.of("id"), "playerB"));

        return out;
    }

    private static void addIfPresent(List<Relation> out,
                                    Set<String> existingKeys,
                                    Map<String, Table> tablesByName,
                                    Relation candidate) {
        if (!tablesByName.containsKey(candidate.fromTable()) || !tablesByName.containsKey(candidate.toTable())) {
            return;
        }

        // Only add if all involved columns exist.
        if (!tableHasColumns(tablesByName.get(candidate.fromTable()), candidate.fromColumns())) return;
        if (!tableHasColumns(tablesByName.get(candidate.toTable()), candidate.toColumns())) return;

        String key = relKey(candidate.fromTable(), candidate.toTable(), candidate.fromColumns(), candidate.toColumns());
        if (existingKeys.contains(key)) return;
        existingKeys.add(key);
        out.add(candidate);
    }

    private static boolean tableHasColumns(Table table, List<String> columns) {
        if (table == null || columns == null || columns.isEmpty()) return false;
        Set<String> existing = new HashSet<>();
        for (Column c : table.columns()) {
            existing.add(c.name());
        }
        for (String col : columns) {
            if (!existing.contains(col)) return false;
        }
        return true;
    }

    private static String relKey(String fromTable, String toTable, List<String> fromCols, List<String> toCols) {
        return fromTable + "->" + toTable + "|" + String.join(",", fromCols) + "->" + String.join(",", toCols);
    }

    private static void addJpaManyToOne(List<Relation> out,
                                       Set<String> existingKeys,
                                       Class<?> entityClass,
                                       String fromTable,
                                       String fromPkColumn,
                                       String fieldName,
                                       String joinColumn,
                                       String toTable,
                                       String toPkColumn,
                                       String relName) {
        try {
            var f = entityClass.getDeclaredField(fieldName);
            if (f.getAnnotation(jakarta.persistence.ManyToOne.class) == null) return;
            var jc = f.getAnnotation(jakarta.persistence.JoinColumn.class);
            if (jc == null) return;

            String fkCol = (jc.name() != null && !jc.name().isBlank()) ? jc.name() : joinColumn;
            Relation r = new Relation(fromTable, List.of(fkCol), toTable, List.of(toPkColumn), relName);
            String key = relKey(r.fromTable(), r.toTable(), r.fromColumns(), r.toColumns());
            if (existingKeys.contains(key)) return;
            existingKeys.add(key);
            out.add(r);
        } catch (NoSuchFieldException ignored) {
            // If the field isn't present, just skip.
        }
    }

    private static Set<String> allowedDomainTables() {
        // Keep it simple: list our entity classes here and extract @Table(name=...) if present.
        // If an entity has no @Table, JPA defaults to the class name; we still include that.
    return Set.of(
        normalizeTableName(tableNameFor(entity.Player.class)),
        normalizeTableName(tableNameFor(entity.Challenges.class)),
        normalizeTableName(tableNameFor(entity.Battle.class)),
        normalizeTableName(tableNameFor(entity.ChallengeCategory.class)),
        normalizeTableName(tableNameFor(entity.Friendship.class)),
        normalizeTableName(tableNameFor(entity.FriendRequest.class)),
        normalizeTableName(tableNameFor(entity.Rank.class))
    );
    }

    private static String tableNameFor(Class<?> entityClass) {
        jakarta.persistence.Table t = entityClass.getAnnotation(jakarta.persistence.Table.class);
        if (t != null && t.name() != null && !t.name().isBlank()) {
            return t.name();
        }
        return entityClass.getSimpleName();
    }

    private static String normalizeTableName(String tableName) {
        return tableName == null ? null : tableName.toLowerCase(Locale.ROOT);
    }

    private static String quoteIdentifier(DatabaseMetaData meta, String identifier) throws Exception {
        String quote = meta.getIdentifierQuoteString();
        if (quote == null || quote.isBlank() || " ".equals(quote)) {
            quote = "\"";
        }
        return quote + identifier + quote;
    }
}
