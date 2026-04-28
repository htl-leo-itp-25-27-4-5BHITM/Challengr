    private static final Map<Long, Map<Long, Integer>> PUSHUP_RESULTS = new ConcurrentHashMap<>();

    private void handlePushupResult(String message, Long playerId) {
        Long battleId = extractLong(message, "battleId");
        int reps = (int) extractDouble(message, "reps"); // reps usually int

        System.out.println("➡️ pushup-result parsed: battleId=" + battleId + ", reps=" + reps);
        if (playerId == null) {
            System.out.println("pushup-result ohne playerId, ignoriere");
            return;
        }

        Battle battle = battleService.findById(battleId);
        if (battle == null) {
            System.out.println("pushup-result: battle " + battleId + " nicht gefunden");
            return;
        }

        PUSHUP_RESULTS
                .computeIfAbsent(battleId, id -> new ConcurrentHashMap<>())
                .put(playerId, reps);

        Map<Long, Integer> map = PUSHUP_RESULTS.get(battleId);
        Long fromId = battle.getFromPlayer().getId();
        Long toId   = battle.getToPlayer().getId();

        if (map.containsKey(fromId) && map.containsKey(toId)) {
            System.out.println("Beide Pushup-Records empfangen -> Werten wir aus!");

            int fromReps = map.get(fromId);
            int toReps   = map.get(toId);

            String winnerName;
            if (fromReps > toReps) {
                winnerName = battle.getFromPlayer().getName();
            } else if (toReps > fromReps) {
                winnerName = battle.getToPlayer().getName();
            } else {
                winnerName = "DRAW"; // Oder Zufall
            }

            System.out.println("Pushup Battle " + battleId + " beendet. From:" + fromReps + " To:" + toReps + ", winner=" + winnerName);

            computeAndBroadcastResult(battle, List.of(winnerName));
            PUSHUP_RESULTS.remove(battleId);
        } else {
            System.out.println("Pushup-Record von " + playerId + " empfangen. "
                    + "Warte noch auf Gegner...");
            // Optionally send PENDING
            String pendingPayload = "{\"type\":\"battle-pending\",\"battleId\":" + battleId + "}";
            sendToPlayer(playerId, pendingPayload);
        }
    }
