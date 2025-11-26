import Foundation

enum NetLogger {
    static func hr(_ title: String = "") {
        print("\n================ \(title) ================\n")
    }
    static func req(_ req: URLRequest) {
        hr("REQUEST")
        print("➡️", req.httpMethod ?? "", req.url?.absoluteString ?? "<nil>")
        if let headers = req.allHTTPHeaderFields, !headers.isEmpty {
            print("📎 Headers:", headers)
        }
        if let body = req.httpBody, !body.isEmpty {
            print("📤 Body:", String(data: body, encoding: .utf8) ?? "<non-utf8>")
        }
    }
    static func resp(_ resp: URLResponse?, data: Data?) {
        hr("RESPONSE")
        if let http = resp as? HTTPURLResponse {
            print("⬅️ Status:", http.statusCode)
            print("⬅️ URL:", http.url?.absoluteString ?? "<nil>")
            print("⬅️ RespHeaders:", http.allHeaderFields)
        } else {
            print("⬅️ Response:", resp ?? "<nil>")
        }
        if let d = data, !d.isEmpty {
            print("⬅️ Body:", String(data: d, encoding: .utf8) ?? "<non-utf8>")
        } else {
            print("⬅️ Body: <empty>")
        }
    }
    static func error(_ e: Error) {
        hr("ERROR")
        print("❌", e.localizedDescription)
        if let urle = e as? URLError { print("URLError.code =", urle.code.rawValue) }
    }
}
