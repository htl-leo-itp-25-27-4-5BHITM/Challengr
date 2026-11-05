package control;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import control.QuestCatalog.Event;
import control.QuestCatalog.Task;
import entity.QuestEventEntity;
import io.quarkus.runtime.StartupEvent;
import jakarta.annotation.Priority;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.inject.Inject;
import jakarta.interceptor.Interceptor;
import jakarta.persistence.EntityManager;
import jakarta.transaction.Transactional;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/** Events aus der Datenbank. Beim allerersten Start wird das Beta-Event angelegt. */
@ApplicationScoped
public class QuestEventStore {

    private static final ObjectMapper JSON = new ObjectMapper();

    @Inject
    EntityManager em;

    void onStart(@Observes @Priority(Interceptor.Priority.APPLICATION + 700) StartupEvent e) {
        seed();
    }

    @Transactional
    void seed() {
        long n = em.createQuery("SELECT COUNT(e) FROM QuestEventEntity e", Long.class).getSingleResult();
        if (n == 0) save(QuestCatalog.BETA);
    }

    public List<Event> list() {
        return em.createQuery("SELECT e FROM QuestEventEntity e", QuestEventEntity.class).getResultStream()
                .map(QuestEventStore::toEvent).sorted(Comparator.comparing(Event::start).reversed()).toList();
    }

    public Optional<Event> find(String id) {
        return Optional.ofNullable(id == null ? null : em.find(QuestEventEntity.class, id)).map(QuestEventStore::toEvent);
    }

    /** Anlegen oder ersetzen (innerhalb einer Transaktion aufrufen). */
    @Transactional
    public Event save(Event e) {
        QuestEventEntity x = em.find(QuestEventEntity.class, e.id());
        boolean isNew = x == null;
        if (isNew) {
            x = new QuestEventEntity();
            x.setId(e.id());
        }
        x.setTitle(e.title());
        x.setSubtitle(e.subtitle());
        x.setStartDate(e.start());
        x.setEndDate(e.end());
        x.setRewardCharacter(e.rewardCharacter());
        x.setRewardCoins(e.rewardCoins());
        try {
            x.setTasksJson(JSON.writeValueAsString(e.tasks()));
        } catch (Exception ex) {
            throw new IllegalArgumentException(ex);
        }
        x.setUpdatedAt(Instant.now());
        if (isNew) em.persist(x);
        return e;
    }

    @Transactional
    public void delete(String id) {
        QuestEventEntity x = em.find(QuestEventEntity.class, id);
        if (x != null) em.remove(x);
    }

    static Event toEvent(QuestEventEntity x) {
        try {
            List<Task> tasks = JSON.readValue(x.getTasksJson(), new TypeReference<>() {});
            return new Event(x.getId(), x.getTitle(), x.getSubtitle(), x.getStartDate(), x.getEndDate(),
                    x.getRewardCharacter(), x.getRewardCoins(), tasks);
        } catch (Exception ex) {
            throw new IllegalStateException("Event " + x.getId() + " nicht lesbar", ex);
        }
    }
}
