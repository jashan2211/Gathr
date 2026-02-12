import SwiftUI
import PassKit

/// Service for wallet pass generation. Currently demo mode only.
/// Real Wallet pass signing requires an Apple Developer certificate + server-side .pkpass creation.
enum WalletPassService {

    // MARK: - Device Capability

    /// Check if PassKit is available on this device
    static var isPassKitAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    // MARK: - Rendered Ticket Card Image

    /// Generate a wallet-sized card image suitable for saving to Photos.
    /// The card mimics an Apple Wallet pass with gradient, event info, and QR code.
    @MainActor
    static func renderTicketCard(
        eventTitle: String,
        ticketNumber: String,
        guestName: String,
        date: Date,
        venue: String?,
        qrCodeData: Data?
    ) -> UIImage? {
        // Wallet-friendly dimensions (roughly 3.375:2.125 ratio at 2x)
        let size = CGSize(width: 375, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // --- Purple-to-pink gradient background ---
            let colors = [
                UIColor(Color.accentPurpleFallback).cgColor,
                UIColor(Color.accentPinkFallback).cgColor
            ]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else { return }

            cgCtx.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // --- Rounded corners clip ---
            let cardRect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 16)
            path.addClip()

            // --- App branding ---
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            ("GATHER" as NSString).draw(at: CGPoint(x: 20, y: 16), withAttributes: brandAttrs)

            // --- Event title ---
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.white
            ]
            let titleMaxWidth = size.width - 40
            let titleRect = CGRect(x: 20, y: 36, width: titleMaxWidth, height: 24)
            (eventTitle as NSString).draw(in: titleRect, withAttributes: titleAttrs)

            // --- Detail lines ---
            let detailAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: date)

            (guestName as NSString).draw(at: CGPoint(x: 20, y: 70), withAttributes: detailAttrs)
            (dateString as NSString).draw(at: CGPoint(x: 20, y: 92), withAttributes: detailAttrs)

            if let venue {
                let venueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.7)
                ]
                (venue as NSString).draw(at: CGPoint(x: 20, y: 114), withAttributes: venueAttrs)
            }

            // --- Ticket number ---
            let ticketAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6)
            ]
            (ticketNumber as NSString).draw(at: CGPoint(x: 20, y: size.height - 28), withAttributes: ticketAttrs)

            // --- QR code in bottom-right ---
            if let qrData = qrCodeData, let qrImage = generateQRImage(from: qrData) {
                let qrSize: CGFloat = 72
                let qrRect = CGRect(
                    x: size.width - qrSize - 16,
                    y: size.height - qrSize - 16,
                    width: qrSize,
                    height: qrSize
                )
                // White background behind QR
                UIColor.white.setFill()
                let qrBgPath = UIBezierPath(roundedRect: qrRect.insetBy(dx: -4, dy: -4), cornerRadius: 6)
                qrBgPath.fill()
                qrImage.draw(in: qrRect)
            }
        }
    }

    // MARK: - QR Code Generation

    /// Generate a UIImage QR code from raw Data.
    private static func generateQRImage(from data: Data) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
