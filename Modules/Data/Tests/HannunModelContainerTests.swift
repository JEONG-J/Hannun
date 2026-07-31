//
//  HannunModelContainerTests.swift
//  HannunDataTests
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunData
import HannunDomain
import SwiftData
import Testing

@Suite("HannunModelContainer")
struct HannunModelContainerTests {
    @Test("인메모리 컨테이너가 스키마 전체를 싣는다")
    func loadsEveryEntity() throws {
        let container = try HannunModelContainer.make(inMemory: true)

        #expect(container.schema.entities.count == HannunSchema.models.count)
    }

    @Test("인메모리 컨테이너는 디스크에 파일을 만들지 않는다")
    func staysInMemory() throws {
        let container = try HannunModelContainer.make(inMemory: true)
        let configuration = try #require(container.configurations.first)

        #expect(configuration.isStoredInMemoryOnly)
    }

    /// CloudKit 은 유니크 제약을 지원하지 않는다. 나중에 동기화를 켤 때 스키마를 갈아엎지
    /// 않으려고 지금부터 제약을 지킨다.
    @Test("유니크 제약을 쓰지 않는다")
    func avoidsUniqueConstraints() throws {
        let container = try HannunModelContainer.make(inMemory: true)

        for entity in container.schema.entities {
            for attribute in entity.attributes {
                #expect(
                    !attribute.isUnique,
                    "\(entity.name).\(attribute.name) 에 유니크 제약이 걸려 있습니다."
                )
            }
        }
    }

    /// CloudKit 은 필수 관계를 허용하지 않는다.
    @Test("관계는 모두 optional 이다")
    func keepsRelationshipsOptional() throws {
        let container = try HannunModelContainer.make(inMemory: true)

        for entity in container.schema.entities {
            for relationship in entity.relationships {
                #expect(
                    relationship.isOptional,
                    "\(entity.name).\(relationship.name) 이 필수 관계입니다."
                )
            }
        }
    }
}
