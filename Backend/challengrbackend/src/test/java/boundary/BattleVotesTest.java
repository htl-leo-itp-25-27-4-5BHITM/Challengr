package boundary;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class BattleVotesTest {

    @Test
    void resultOnlyAfterBothPlayersVoted() {
        BattleVotes votes = new BattleVotes();

        assertNull(votes.register(1L, "a", "Alice"));
        List<String> result = votes.register(1L, "b", "Alice");

        assertEquals(List.of("Alice", "Alice"), result);
        assertEquals(0, votes.count(1L), "Battle wird nach dem Ergebnis zurückgesetzt");
    }

    @Test
    void samePlayerCannotVoteTwice() {
        BattleVotes votes = new BattleVotes();

        assertNull(votes.register(1L, "a", "Alice"));
        assertNull(votes.register(1L, "a", "Alice"), "Doppelter Vote darf das Battle nicht entscheiden");
        assertEquals(1, votes.count(1L));

        assertEquals(List.of("Alice", "Bob"), votes.register(1L, "b", "Bob"));
    }

    @Test
    void battlesAreIndependent() {
        BattleVotes votes = new BattleVotes();

        assertNull(votes.register(1L, "a", "Alice"));
        assertNull(votes.register(2L, "b", "Bob"));
        assertEquals(1, votes.count(1L));
        assertEquals(1, votes.count(2L));
    }

    @Test
    void ignoresIncompleteVotes() {
        BattleVotes votes = new BattleVotes();

        assertNull(votes.register(1L, null, "Alice"));
        assertNull(votes.register(1L, "a", null));
        assertEquals(0, votes.count(1L));
    }

    @Test
    void clearForgetsVotes() {
        BattleVotes votes = new BattleVotes();
        votes.register(1L, "a", "a");
        votes.clear(1L);

        assertEquals(0, votes.count(1L));
        assertNull(votes.register(1L, "b", "a"), "Nach dem Zurücksetzen fehlt wieder eine Stimme");
    }

    @Test
    void manyParallelVotesStillNeedTwoPlayers() throws Exception {
        BattleVotes votes = new BattleVotes();
        var pool = java.util.concurrent.Executors.newFixedThreadPool(8);
        var results = new java.util.concurrent.ConcurrentLinkedQueue<List<String>>();

        for (int i = 0; i < 100; i++) {
            String player = (i % 2 == 0) ? "a" : "b";
            pool.submit(() -> {
                List<String> r = votes.register(7L, player, "a");
                if (r != null) results.add(r);
            });
        }
        pool.shutdown();
        assertTrue(pool.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS));

        // Jede Runde braucht a UND b – nie zwei Stimmen desselben Spielers
        assertFalse(results.isEmpty());
        results.forEach(r -> assertEquals(2, r.size()));
    }
}
