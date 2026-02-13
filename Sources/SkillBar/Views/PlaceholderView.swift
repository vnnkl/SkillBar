import SwiftUI

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            placeholderList
            Divider()
            footer
        }
        .frame(width: 400, height: 500)
    }

    private var header: some View {
        HStack {
            Image(systemName: "terminal")
                .font(.title3)
            Text("SkillBar")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var placeholderList: some View {
        List {
            Section("Skills") {
                ForEach(sampleSkills, id: \.self) { skill in
                    Text(skill)
                        .font(.body.monospaced())
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var footer: some View {
        HStack {
            Text("0 skills")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var sampleSkills: [String] {
        ["/commit", "/docker-optimize", "/tdd"]
    }
}
