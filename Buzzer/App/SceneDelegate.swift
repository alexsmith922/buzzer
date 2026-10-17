import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: BuzzerViewController())
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Runs on first launch and every return to the app, so sounds that couldn't
        // download (no signal, airplane mode) are picked up once there's a connection.
        SoundDownloader.shared.downloadMissingSounds()
    }
}
