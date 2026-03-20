import SwiftUI

// MARK: - Detail row components matching Docker Desktop style

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Spacer()
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.body)
        .padding(.horizontal)
        .padding(.vertical, 8)
        Divider()
            .padding(.leading)
    }
}

struct DetailSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

struct DetailTableHeader: View {
    let columns: [String]

    var body: some View {
        HStack {
            ForEach(columns, id: \.self) { column in
                Text(column)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.5))
    }
}

struct DetailTableRow: View {
    let columns: [String]

    var body: some View {
        HStack {
            ForEach(columns, id: \.self) { column in
                Text(column)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        Divider()
            .padding(.leading)
    }
}
