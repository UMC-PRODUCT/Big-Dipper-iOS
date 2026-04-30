//
//  File.swift
//  AppProductTestServer
//
//  Created by euijjang97 on 1/10/26.
//


import Vapor

struct TestController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.get("test", use: testEndpoint)
        routes.get("public", use: publicEndpoint)
        routes.post("test", use: testPostEndpoint)
        routes.get("test", "token", "access", use: issueAccessToken)

        routes.get("protected", use: protectedEndpoint)
        routes.get("user", use: getUserEndpoint)
        routes.get("users", use: getUsersEndpoint)
        routes.get("posts", use: getPostsEndpoint)
    }

    // MARK: - Public Endpoints
    @Sendable
    func testEndpoint(req: Request) async throws -> CommonDTO<String> {
        return CommonDTO.success("테스트 성공")
    }

    @Sendable
    func testPostEndpoint(req: Request) async throws -> CommonDTO<String> {
        return CommonDTO.success("테스트 성공")
    }

    @Sendable
    func issueAccessToken(req: Request) async throws -> CommonDTO<String> {
        CommonDTO.success("valid_token")
    }

    @Sendable
    func publicEndpoint(req: Request) async throws -> CommonDTO<String> {
        return CommonDTO.success("테스트 성공")
    }

    // MARK: - Protected Endpoints
    @Sendable
    func protectedEndpoint(req: Request) async throws -> CommonDTO<String> {
        try validateAuthorizationHeader(req)
        return CommonDTO.success("보호 성공")
    }
    
    @Sendable
    func getUserEndpoint(req: Request) async throws -> CommonDTO<UserDTO> {
        try validateAuthorizationHeader(req)

        let user = UserDTO(
            id: 1,
            name: "Test User",
            email: "test@jeong.com"
        )
        return CommonDTO.success(user)
    }

    @Sendable
    func getUsersEndpoint(req: Request) async throws -> CommonDTO<[UserDTO]> {
        try validateAuthorizationHeader(req)

        let users = [
            UserDTO(id: 1, name: "User 1", email: "user1@jeong.com"),
            UserDTO(id: 2, name: "User 2", email: "user2@jeong.com"),
            UserDTO(id: 3, name: "User 3", email: "user3@jeong.com")
        ]
        return CommonDTO.success(users)
    }

    @Sendable
    func getPostsEndpoint(req: Request) async throws -> CommonDTO<[PostDTO]> {
        try validateAuthorizationHeader(req)

        let posts = [
            PostDTO(id: 1, title: "1번 post", body: "1번 post", userId: 1),
            PostDTO(id: 2, title: "2번 post", body: "2번 post", userId: 2),
            PostDTO(id: 3, title: "3번 post", body: "3번 post", userId: 3)
        ]
        return CommonDTO.success(posts)
    }

    // MARK: - Helper Methods
    private func validateAuthorizationHeader(_ req: Request) throws {
        guard let authHeader = req.headers[.authorization].first else {
            throw Abort(.unauthorized, reason:  "Authorization 없음")
        }

        guard authHeader.hasPrefix("Bearer ") else {
            throw Abort(.unauthorized, reason: "Authorization 유효하지 않음")
        }

        let token = String(authHeader.dropFirst("Bearer ".count))

        if token.isEmpty {
            throw Abort(.unauthorized, reason: "token 없음")
        }

        if token == "expired_token" || token == "access_token 유효하지 않음" {
            throw Abort(.unauthorized, reason: "Token 만료 또는 유효 하지 않음")
        }

        if token == "forbidden_token" {
            throw Abort(.forbidden, reason: "접근 금지")
        }
    }
}
