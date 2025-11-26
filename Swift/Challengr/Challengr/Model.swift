//
//  ModelService.swift
//  Challengr
//
//  Created by Julian Richter on 15.10.25.
//

import Foundation

@Observable class Model {
    var challenges: [Challenge] = []
}

struct Challenge: Identifiable, Hashable, Codable {

    var id: Int
    var name: String
        
}

struct Player: Codable {
    let latitude: Double
    let longitude: Double
    let name: String
}
