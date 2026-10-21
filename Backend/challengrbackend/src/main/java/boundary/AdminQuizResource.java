package boundary;

import control.AdminAudit;
import control.BattleMode;
import control.ChallengeCategoriesRepository;
import control.QuizQuestionSync;
import entity.ChallengeCategory;
import entity.Challenges;
import entity.QuizReport;
import entity.QuizStat;
import jakarta.annotation.security.RolesAllowed;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;

import java.util.*;
import java.util.stream.Collectors;

/** Quizfragen im Dashboard: suchen, anlegen, bearbeiten, deaktivieren; Meldungen und Antwort-Statistik. */
@Path("/api/admin/quiz")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@RolesAllowed("admin")
public class AdminQuizResource {

    /** Ab so vielen Antworten ist die Quote aussagekräftig. */
    static final int MIN_ANSWERS = 8;
    /** Darunter gilt eine Frage als „fast alle falsch“. */
    static final double HARD_RATE = 0.25;

    public record QuestionDTO(long id, String text, List<String> choices, int correctIndex, boolean active, boolean edited,
                              long answers, long correct, long wrong, long unanswered, Double correctRate, boolean hard,
                              long openReports) {}

    public record QuestionInput(String text, List<String> choices, Integer correctIndex) {}

    public record ReportDTO(long id, long questionId, String questionText, String reason, String comment, String status,
                            String createdAt, String playerName) {}

    @Inject
    EntityManager em;

    @Inject
    ChallengeCategoriesRepository categories;

    @Inject
    AdminAudit audit;

    /** filter: all | active | inactive | hard | reported */
    @GET
    @Path("/questions")
    @Transactional
    public List<QuestionDTO> list(@QueryParam("q") String query, @QueryParam("filter") @DefaultValue("all") String filter) {
        Map<Long, QuizStat> stats = em.createQuery("SELECT s FROM QuizStat s", QuizStat.class).getResultStream()
                .collect(Collectors.toMap(QuizStat::getChallengeId, s -> s));
        Map<Long, Long> reports = em.createQuery(
                        "SELECT r.challengeId, COUNT(r) FROM QuizReport r WHERE r.status = :s GROUP BY r.challengeId", Object[].class)
                .setParameter("s", QuizReport.Status.OPEN).getResultStream()
                .collect(Collectors.toMap(r -> (Long) r[0], r -> (Long) r[1]));
        String q = query == null ? "" : query.trim().toLowerCase();
        return knowledge().stream()
                .filter(c -> q.isEmpty() || c.getText().toLowerCase().contains(q)
                        || choices(c).stream().anyMatch(o -> o != null && o.toLowerCase().contains(q)))
                .map(c -> toDTO(c, stats.get(c.getId()), reports.getOrDefault(c.getId(), 0L)))
                .filter(d -> switch (filter) {
                    case "active" -> d.active();
                    case "inactive" -> !d.active();
                    case "hard" -> d.hard();
                    case "reported" -> d.openReports() > 0;
                    default -> true;
                })
                .sorted(Comparator.comparingLong(QuestionDTO::openReports).reversed()
                        .thenComparing(QuestionDTO::hard, Comparator.reverseOrder())
                        .thenComparing(QuestionDTO::id, Comparator.reverseOrder()))
                .toList();
    }

    @POST
    @Path("/questions")
    @Transactional
    public QuestionDTO create(QuestionInput in) {
        validate(in);
        ChallengeCategory wissen = categories.findByName(BattleMode.KNOWLEDGE_CATEGORY);
        if (wissen == null) throw new WebApplicationException("Kategorie Wissen fehlt", 500);
        if (textTaken(in.text().trim(), null)) throw new WebApplicationException("Diese Frage gibt es schon", 409);
        Challenges c = new Challenges(in.text().trim(), wissen);
        apply(c, in);
        em.persist(c);
        audit.log("QUIZ_NEW", null, null, null, c.getText(), "Neue Quizfrage");
        return toDTO(c, null, 0);
    }

    @PUT
    @Path("/questions/{id}")
    @Transactional
    public QuestionDTO update(@PathParam("id") long id, QuestionInput in) {
        validate(in);
        Challenges c = find(id);
        String text = in.text().trim();
        if (textTaken(text, id)) throw new WebApplicationException("Diese Frage gibt es schon", 409);
        String before = c.getText() + " → " + choices(c).get(c.getCorrectIndex());
        if (!text.equals(c.getText()) && c.getOriginalText() == null) c.setOriginalText(c.getText());
        c.setText(text);
        apply(c, in);
        audit.log("QUIZ_EDIT", null, null, before, c.getText() + " → " + choices(c).get(c.getCorrectIndex()), "Quizfrage bearbeitet");
        return toDTO(c, em.find(QuizStat.class, id), openReports(id));
    }

    public record ActiveInput(boolean active) {}

    @PUT
    @Path("/questions/{id}/active")
    @Transactional
    public QuestionDTO setActive(@PathParam("id") long id, ActiveInput in) {
        Challenges c = find(id);
        if (in != null && c.isActive() != in.active()) {
            c.setActive(in.active());
            audit.log(in.active() ? "QUIZ_ON" : "QUIZ_OFF", null, null, null, c.getText(), "Quizfrage " + (in.active() ? "aktiviert" : "deaktiviert"));
        }
        return toDTO(c, em.find(QuizStat.class, id), openReports(id));
    }

    @GET
    @Path("/reports")
    @Transactional
    public List<ReportDTO> reports(@QueryParam("status") @DefaultValue("OPEN") String status) {
        var query = "ALL".equals(status)
                ? em.createQuery("SELECT r FROM QuizReport r ORDER BY r.createdAt DESC", QuizReport.class)
                : em.createQuery("SELECT r FROM QuizReport r WHERE r.status = :s ORDER BY r.createdAt DESC", QuizReport.class)
                        .setParameter("s", QuizReport.Status.OPEN);
        return query.setMaxResults(300).getResultStream().map(r -> {
            Challenges c = em.find(Challenges.class, r.getChallengeId());
            entity.Player p = em.find(entity.Player.class, r.getPlayerId());
            return new ReportDTO(r.getId(), r.getChallengeId(), c == null ? "?" : c.getText(), r.getReason().name(), r.getComment(),
                    r.getStatus().name(), r.getCreatedAt().toString(), p == null ? null : p.getName());
        }).toList();
    }

    /** Alle offenen Meldungen zu einer Frage auf einmal erledigen (nach dem Korrigieren). */
    @POST
    @Path("/questions/{id}/reports/resolve")
    @Consumes(MediaType.WILDCARD)
    @Transactional
    public QuestionDTO resolveReports(@PathParam("id") long id) {
        Challenges c = find(id);
        int n = em.createQuery("UPDATE QuizReport r SET r.status = :done WHERE r.challengeId = :c AND r.status = :open")
                .setParameter("done", QuizReport.Status.RESOLVED).setParameter("open", QuizReport.Status.OPEN)
                .setParameter("c", id).executeUpdate();
        if (n > 0) audit.log("QUIZ_REPORTS", null, null, n, 0, "Meldungen zur Frage erledigt: " + c.getText());
        return toDTO(c, em.find(QuizStat.class, id), 0);
    }

    // ---------------------------------------------------------

    private List<Challenges> knowledge() {
        return em.createQuery("SELECT c FROM Challenges c WHERE c.challengeCategory.name = :k AND c.correctIndex IS NOT NULL",
                Challenges.class).setParameter("k", BattleMode.KNOWLEDGE_CATEGORY).getResultList();
    }

    private Challenges find(long id) {
        Challenges c = em.find(Challenges.class, id);
        if (c == null || c.getCorrectIndex() == null) throw new WebApplicationException("Frage nicht gefunden", 404);
        return c;
    }

    private boolean textTaken(String text, Long exceptId) {
        return knowledge().stream().anyMatch(c -> (exceptId == null || c.getId() != exceptId)
                && (c.getText().equalsIgnoreCase(text) || text.equalsIgnoreCase(c.getOriginalText())));
    }

    private long openReports(long id) {
        return em.createQuery("SELECT COUNT(r) FROM QuizReport r WHERE r.challengeId = :c AND r.status = :s", Long.class)
                .setParameter("c", id).setParameter("s", QuizReport.Status.OPEN).getSingleResult();
    }

    static void validate(QuestionInput in) {
        if (in == null || in.text() == null || in.text().trim().length() < 5 || in.text().trim().length() > 300) {
            throw new WebApplicationException("Frage: 5–300 Zeichen", 400);
        }
        if (in.choices() == null || in.choices().size() != 4) throw new WebApplicationException("Genau 4 Antworten", 400);
        Set<String> seen = new HashSet<>();
        for (String c : in.choices()) {
            if (c == null || c.isBlank() || c.trim().length() > 80) throw new WebApplicationException("Antworten: 1–80 Zeichen", 400);
            if (!seen.add(c.trim().toLowerCase())) throw new WebApplicationException("Zwei Antworten sind gleich", 400);
        }
        if (in.correctIndex() == null || in.correctIndex() < 0 || in.correctIndex() > 3) {
            throw new WebApplicationException("Richtige Antwort wählen", 400);
        }
    }

    private static void apply(Challenges c, QuestionInput in) {
        c.setOptionA(in.choices().get(0).trim());
        c.setOptionB(in.choices().get(1).trim());
        c.setOptionC(in.choices().get(2).trim());
        c.setOptionD(in.choices().get(3).trim());
        c.setCorrectIndex(in.correctIndex());
    }

    private static List<String> choices(Challenges c) {
        return Arrays.asList(c.getOptionA(), c.getOptionB(), c.getOptionC(), c.getOptionD());
    }

    static QuestionDTO toDTO(Challenges c, QuizStat s, long reports) {
        long correct = s == null ? 0 : s.getCorrect(), wrong = s == null ? 0 : s.getWrong(), none = s == null ? 0 : s.getUnanswered();
        long total = correct + wrong + none;
        Double rate = total == 0 ? null : (double) correct / total;
        boolean hard = total >= MIN_ANSWERS && rate != null && rate < HARD_RATE;
        return new QuestionDTO(c.getId(), c.getText(), choices(c), c.getCorrectIndex(), c.isActive(), c.getOriginalText() != null,
                total, correct, wrong, none, rate, hard, reports);
    }
}
