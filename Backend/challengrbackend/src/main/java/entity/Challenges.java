package entity;

import jakarta.persistence.*;

@Entity
@Table(name = "challenges")
public class Challenges {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private long id;
}
