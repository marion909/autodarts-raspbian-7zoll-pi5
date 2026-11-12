import XCTest
@testable import AutodartsControlCore

final class StatusParserTests: XCTestCase {
    let sample = """
    ctl_version=1
    hostname=Autodarts
    ips=192.168.1.50,10.0.0.7
    os=Debian GNU/Linux 13 (trixie)
    uptime_seconds=3725
    throttled=0x50005
    temp_c=51.2
    mem_used_mb=812
    mem_total_mb=7943
    disk_used=23%
    session=x11
    autodarts_version=2.1.1
    autodarts_running=1
    kiosk_running=0
    channel=beta
    web_port=3181
    rotation=right
    dsi_mode=800x480
    dsi_scale=1.2x1.2
    mirror=0
    bt_mac=11:22:33:44:55:66
    bt_name=JBL Flip 5
    bt_connected=1
    ssh_active=active
    garbage line without equals
    =novalue
    """

    func testParsesValues() {
        let status = PiStatus(parsing: sample)
        XCTAssertTrue(status.isValid)
        XCTAssertEqual(status.hostname, "Autodarts")
        XCTAssertEqual(status.ips, ["192.168.1.50", "10.0.0.7"])
        XCTAssertEqual(status.os, "Debian GNU/Linux 13 (trixie)")
        XCTAssertEqual(status.uptimeSeconds, 3725)
        XCTAssertEqual(status.temperatureC, 51.2)
        XCTAssertEqual(status.memUsedMB, 812)
        XCTAssertEqual(status.diskUsed, "23%")
        XCTAssertEqual(status.autodartsVersion, "2.1.1")
        XCTAssertTrue(status.autodartsRunning)
        XCTAssertFalse(status.kioskRunning)
        XCTAssertEqual(status.channel, "beta")
        XCTAssertEqual(status.webPort, 3181)
        XCTAssertEqual(status.rotation, .right)
        XCTAssertFalse(status.mirror)
        XCTAssertEqual(status.btName, "JBL Flip 5")
        XCTAssertTrue(status.btConnected)
        XCTAssertTrue(status.sshActive)
    }

    func testValueMayContainEqualsSign() {
        let status = PiStatus(parsing: "ctl_version=1\nos=a=b")
        XCTAssertEqual(status.os, "a=b")
    }

    func testDefaultsForMissingKeys() {
        let status = PiStatus(parsing: "ctl_version=1")
        XCTAssertEqual(status.webPort, 3180)
        XCTAssertEqual(status.channel, "stable")
        XCTAssertEqual(status.rotation, .normal)
        XCTAssertEqual(status.dsiScale, "1.2x1.2")
        XCTAssertFalse(status.hasBluetoothSpeaker)
        XCTAssertNil(status.throttled)
    }

    func testInvalidWithoutVersion() {
        XCTAssertFalse(PiStatus(parsing: "hostname=x").isValid)
    }
}

final class ThrottledTests: XCTestCase {
    func testClean() {
        let t = Throttled(hex: "0x0")
        XCTAssertEqual(t?.isClean, true)
        XCTAssertEqual(t?.hasActiveProblem, false)
        XCTAssertEqual(t?.descriptions, [])
    }

    func testFlags() {
        let t = Throttled(hex: "0x50005")
        XCTAssertEqual(t?.underVoltageNow, true)
        XCTAssertEqual(t?.throttledNow, true)
        XCTAssertEqual(t?.underVoltageOccurred, true)
        XCTAssertEqual(t?.throttledOccurred, true)
        XCTAssertEqual(t?.frequencyCappedNow, false)
        XCTAssertEqual(t?.hasActiveProblem, true)
    }

    func testOccurredOnlyIsNotActive() {
        let t = Throttled(hex: "0x10000")
        XCTAssertEqual(t?.underVoltageOccurred, true)
        XCTAssertEqual(t?.hasActiveProblem, false)
        XCTAssertEqual(t?.isClean, false)
    }

    func testInvalid() {
        XCTAssertNil(Throttled(hex: ""))
        XCTAssertNil(Throttled(hex: "zz"))
    }
}

final class BluetoothParserTests: XCTestCase {
    func testParsesTabSeparatedList() {
        let text = "11:22:33:44:55:66\tJBL Flip 5\t1\n22:33:44:55:66:77\tMein Fernseher\t0\nbroken line\nZZ:22:33:44:55:66\tBad\t1\n"
        let devices = BluetoothDevice.parse(text)
        XCTAssertEqual(devices, [
            BluetoothDevice(mac: "11:22:33:44:55:66", name: "JBL Flip 5", isAudio: true),
            BluetoothDevice(mac: "22:33:44:55:66:77", name: "Mein Fernseher", isAudio: false),
        ])
    }
}

final class ValidationTests: XCTestCase {
    func testHost() {
        XCTAssertTrue(Validation.isValidHost("Autodarts.local"))
        XCTAssertTrue(Validation.isValidHost("192.168.1.50"))
        XCTAssertFalse(Validation.isValidHost("-oProxyCommand=evil"))
        XCTAssertFalse(Validation.isValidHost("a b"))
        XCTAssertFalse(Validation.isValidHost(""))
        XCTAssertFalse(Validation.isValidHost("host;rm"))
    }

    func testUser() {
        XCTAssertTrue(Validation.isValidUser("pi"))
        XCTAssertFalse(Validation.isValidUser("Pi"))
        XCTAssertFalse(Validation.isValidUser("-x"))
        XCTAssertFalse(Validation.isValidUser("a b"))
    }

    func testMAC() {
        XCTAssertTrue(Validation.isValidMAC("AA:bb:CC:dd:EE:ff"))
        XCTAssertFalse(Validation.isValidMAC("AA:bb:CC:dd:EE"))
        XCTAssertFalse(Validation.isValidMAC("AA-bb-CC-dd-EE-ff"))
    }

    func testScaleAndMode() {
        XCTAssertTrue(Validation.isValidScale("1.2x1.2"))
        XCTAssertTrue(Validation.isValidScale("1x1"))
        XCTAssertFalse(Validation.isValidScale("abc"))
        XCTAssertTrue(Validation.isValidMode("800x480"))
        XCTAssertFalse(Validation.isValidMode("800*480"))
    }

    func testPublicKey() {
        XCTAssertTrue(Validation.isValidPublicKey("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabc autodarts-control"))
        XCTAssertFalse(Validation.isValidPublicKey("ssh-ed25519 AAAA'; rm -rf / #"))
    }

    func testShellQuote() {
        XCTAssertEqual(Validation.shellQuote("abc"), "'abc'")
        XCTAssertEqual(Validation.shellQuote("it's"), "'it'\\''s'")
    }
}

final class CtlCommandTests: XCTestCase {
    func testCommandQuotesArguments() {
        XCTAssertEqual(Ctl.command("display-set", "right", "1.2x1.2", "1", "800x480"),
                       "/usr/local/bin/autodarts-ctl 'display-set' 'right' '1.2x1.2' '1' '800x480'")
        XCTAssertEqual(Ctl.command("status"), "/usr/local/bin/autodarts-ctl 'status'")
    }

    func testAuthorizeKeyCommand() {
        let cmd = Ctl.authorizeKeyCommand(publicKey: "ssh-ed25519 AAAA x")
        XCTAssertTrue(cmd.contains("grep -qxF 'ssh-ed25519 AAAA x'"))
        XCTAssertTrue(cmd.contains("authorized_keys"))
    }

    func testBootstrapContainsInstallerURL() {
        let cmd = Ctl.bootstrapCommand()
        XCTAssertTrue(cmd.contains("https://raw.githubusercontent.com/marion909/autodarts-raspbian-7zoll-pi5/main/install.sh"))
        XCTAssertTrue(cmd.contains("BT_SPEAKER=no"))
        XCTAssertTrue(cmd.contains("sudo -S -p ''"))
        XCTAssertFalse(cmd.contains("| sudo"), "stdin muss dem Passwort gehoeren, nicht dem Installer")
    }
}

final class SSHClientTests: XCTestCase {
    func testClassify() {
        func r(_ status: Int32, _ err: String, timedOut: Bool = false) -> SSHResult {
            SSHResult(status: status, stdout: Data(), stderr: err, timedOut: timedOut)
        }
        XCTAssertEqual(SSHFailure.classify(r(0, "")), .none)
        XCTAssertEqual(SSHFailure.classify(r(255, "pi@host: Permission denied (publickey,password).")), .authentication)
        XCTAssertEqual(SSHFailure.classify(r(255, "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!")), .hostKeyChanged)
        XCTAssertEqual(SSHFailure.classify(r(255, "ssh: connect to host x port 22: Connection refused")),
                       .unreachable("ssh: connect to host x port 22: Connection refused"))
        XCTAssertEqual(SSHFailure.classify(r(1, "boom")), .commandFailed(1))
        XCTAssertEqual(SSHFailure.classify(r(15, "", timedOut: true)), .timeout)
    }

    func testRejectsInvalidHostWithoutRunning() async {
        let client = SSHClient(config: SSHConfig(host: "-oProxyCommand=evil", user: "pi"))
        let result = await client.run("true")
        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.stderr.contains("Ungültiger"))
    }

    func testArgumentsContainBatchModeAndTarget() {
        let client = SSHClient(config: SSHConfig(host: "Autodarts.local", user: "pi", identityPath: "/tmp/key"))
        let args = client.arguments(command: "true")
        XCTAssertTrue(args.contains("BatchMode=yes"))
        XCTAssertTrue(args.contains("pi@Autodarts.local"))
        XCTAssertEqual(args.last, "true")
    }

    /// Fake-ssh: prueft Prozessstart, Ausgabe, Exit-Code und Live-Streaming ohne Netzwerk
    func testRunProcessCapturesOutputAndStreams() async {
        let collector = LockedStrings()
        let result = await runProcess(
            executable: "/bin/sh",
            arguments: ["-c", "echo hallo; echo fehler 1>&2; exit 3"],
            timeout: 10,
            onOutput: { collector.append($0) }
        )
        XCTAssertEqual(result.status, 3)
        XCTAssertEqual(result.text, "hallo\n")
        XCTAssertEqual(result.stderr, "fehler\n")
        XCTAssertTrue(collector.joined.contains("hallo"))
    }

    func testRunProcessPassesStdin() async {
        let result = await runProcess(
            executable: "/bin/sh",
            arguments: ["-c", "read -r line; echo \"got:$line\""],
            stdin: Data("geheim\n".utf8),
            timeout: 10
        )
        XCTAssertEqual(result.text, "got:geheim\n")
    }

    func testNeedsSudoPasswordDetection() {
        let yes = SSHResult(status: 1, stdout: Data(), stderr: "sudo: a password is required\n")
        let no = SSHResult(status: 1, stdout: Data(), stderr: "boom")
        XCTAssertTrue(yes.needsSudoPassword)
        XCTAssertFalse(no.needsSudoPassword)
    }

    func testRunProcessTimeout() async {
        let result = await runProcess(executable: "/bin/sleep", arguments: ["5"], timeout: 0.5)
        XCTAssertTrue(result.timedOut)
        XCTAssertFalse(result.succeeded)
    }
}

private final class LockedStrings: @unchecked Sendable {
    private var parts: [String] = []
    private let lock = NSLock()
    func append(_ s: String) { lock.lock(); parts.append(s); lock.unlock() }
    var joined: String { lock.lock(); defer { lock.unlock() }; return parts.joined() }
}
