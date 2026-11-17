import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import media from '@ohos.multimedia.media';
import avSession from '@ohos.multimedia.avsession';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import window from '@ohos.window';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';

const TAG = 'OhosAudioPlugin';

/**
 * Native HarmonyOS NEXT (OHOS) audio bridge plugin for AuraMusic.
 *
 * Registers on MethodChannel `com.auramusic/ohos_audio` and wires:
 * - `@ohos.multimedia.media` (AVPlayer) for audio playback
 * - `@ohos.multimedia.avsession` (AVSession) for system media controls & metadata
 * - `@ohos.resourceschedule.backgroundTaskManager` for `audioPlayback` background keep-alive
 * - `@ohos.window` subWindow stub for floating desktop lyrics
 */
export default class OhosAudioPlugin implements FlutterPlugin, MethodCallHandler {
  private static readonly CHANNEL_NAME: string = 'com.auramusic/ohos_audio';
  private static readonly LYRICS_WINDOW_NAME: string = 'AuraDesktopLyrics';

  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private avPlayer: media.AVPlayer | null = null;
  private session: avSession.AVSession | null = null;
  private lyricsSubWindow: window.Window | null = null;

  private isBackgroundRunning: boolean = false;
  private currentQuality: string = 'hiRes';
  private currentTrackId: string = '';

  getUniqueClassName(): string {
    return 'OhosAudioPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext() as common.UIAbilityContext;
    this.channel = new MethodChannel(binding.getBinaryMessenger(), OhosAudioPlugin.CHANNEL_NAME);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    this.releaseResources();
    this.context = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'playTrack':
      case 'play':
        this.handlePlay(call, result);
        break;
      case 'pause':
        this.handlePause(result);
        break;
      case 'resume':
        this.handleResume(result);
        break;
      case 'seek':
        this.handleSeek(call, result);
        break;
      case 'stop':
        this.handleStop(result);
        break;
      case 'setQuality':
        this.handleSetQuality(call, result);
        break;
      case 'updateMetadata':
      case 'updateSessionMetadata':
        this.handleUpdateMetadata(call, result);
        break;
      case 'updatePlaybackState':
        this.handleUpdatePlaybackState(call, result);
        break;
      case 'setDesktopLyricsEnabled':
      case 'setDesktopLyrics':
        this.handleSetDesktopLyrics(call, result);
        break;
      case 'updateDesktopLyricLine':
        this.handleUpdateDesktopLyricLine(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * Starts AVPlayer playback for the requested track and syncs AVSession + background task.
   */
  private async handlePlay(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const id = (call.argument('id') as string) ?? '';
      const title = (call.argument('title') as string) ?? 'Unknown Title';
      const artist = (call.argument('artist') as string) ?? 'Unknown Artist';
      const album = (call.argument('album') as string) ?? '';
      const durationSeconds = (call.argument('durationSeconds') as number) ?? 0;
      const sourceId = (call.argument('sourceId') as string) ?? (call.argument('url') as string) ?? '';
      const quality = (call.argument('quality') as string) ?? this.currentQuality;

      this.currentTrackId = id;
      this.currentQuality = quality;

      const player = await this.ensureAvPlayer();
      await this.ensureAvSession();
      await this.startBackgroundTask();

      await player.reset();
      if (sourceId.length > 0) {
        player.url = sourceId;
      }

      await this.syncAvSessionMetadata(id, title, artist, album, durationSeconds);
      await this.syncAvSessionPlaybackState(true, 0);

      result.success(null);
    } catch (err) {
      this.reportError(result, 'PLAY_FAILED', err);
    }
  }

  private async handlePause(result: MethodResult): Promise<void> {
    try {
      if (this.avPlayer !== null && this.avPlayer.state === 'playing') {
        await this.avPlayer.pause();
      }
      const posSeconds = this.avPlayer !== null ? Math.floor(this.avPlayer.currentTime / 1000) : 0;
      await this.syncAvSessionPlaybackState(false, posSeconds);
      result.success(null);
    } catch (err) {
      this.reportError(result, 'PAUSE_FAILED', err);
    }
  }

  private async handleResume(result: MethodResult): Promise<void> {
    try {
      await this.startBackgroundTask();
      if (this.avPlayer !== null &&
        (this.avPlayer.state === 'paused' || this.avPlayer.state === 'prepared')) {
        await this.avPlayer.play();
      }
      const posSeconds = this.avPlayer !== null ? Math.floor(this.avPlayer.currentTime / 1000) : 0;
      await this.syncAvSessionPlaybackState(true, posSeconds);
      result.success(null);
    } catch (err) {
      this.reportError(result, 'RESUME_FAILED', err);
    }
  }

  private async handleSeek(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const positionSeconds = Math.max(0, (call.argument('positionSeconds') as number) ?? 0);
      if (this.avPlayer !== null) {
        this.avPlayer.seek(positionSeconds * 1000, media.SeekMode.SEEK_CLOSEST);
      }
      const isPlaying = this.avPlayer !== null && this.avPlayer.state === 'playing';
      await this.syncAvSessionPlaybackState(isPlaying, positionSeconds);
      result.success(null);
    } catch (err) {
      this.reportError(result, 'SEEK_FAILED', err);
    }
  }

  private async handleStop(result: MethodResult): Promise<void> {
    try {
      if (this.avPlayer !== null) {
        await this.avPlayer.stop();
        await this.avPlayer.reset();
      }
      await this.syncAvSessionPlaybackState(false, 0);
      await this.stopBackgroundTask();
      result.success(null);
    } catch (err) {
      this.reportError(result, 'STOP_FAILED', err);
    }
  }

  private handleSetQuality(call: MethodCall, result: MethodResult): void {
    const quality = (call.argument('quality') as string) ?? 'hiRes';
    this.currentQuality = quality;
    console.info(`${TAG}: Active audio quality set to ${this.currentQuality}`);
    result.success(null);
  }

  private async handleUpdateMetadata(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const id = (call.argument('id') as string) ?? this.currentTrackId;
      const title = (call.argument('title') as string) ?? 'Unknown Title';
      const artist = (call.argument('artist') as string) ?? 'Unknown Artist';
      const album = (call.argument('album') as string) ?? '';
      const durationSeconds = (call.argument('durationSeconds') as number) ?? 0;

      await this.ensureAvSession();
      await this.syncAvSessionMetadata(id, title, artist, album, durationSeconds);
      result.success(null);
    } catch (err) {
      this.reportError(result, 'METADATA_FAILED', err);
    }
  }

  private async handleUpdatePlaybackState(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const isPlaying = (call.argument('isPlaying') as boolean) ?? false;
      const positionSeconds = Math.max(0, (call.argument('positionSeconds') as number) ?? 0);
      await this.ensureAvSession();
      await this.syncAvSessionPlaybackState(isPlaying, positionSeconds);
      result.success(null);
    } catch (err) {
      this.reportError(result, 'PLAYBACK_STATE_FAILED', err);
    }
  }

  private async handleSetDesktopLyrics(call: MethodCall, result: MethodResult): Promise<void> {
    try {
      const enabled = (call.argument('enabled') as boolean) ?? false;
      const currentLyric = (call.argument('currentLyric') as string) ?? '';
      await this.toggleLyricsSubWindow(enabled, currentLyric);
      result.success(null);
    } catch (err) {
      this.reportError(result, 'DESKTOP_LYRICS_FAILED', err);
    }
  }

  private handleUpdateDesktopLyricLine(call: MethodCall, result: MethodResult): void {
    const line = (call.argument('line') as string) ?? '';
    // Forward lyric line to the floating subWindow UI via AppStorage when active.
    AppStorage.setOrCreate('auraDesktopLyricLine', line);
    result.success(null);
  }

  /**
   * Lazily creates and wires the HarmonyOS AVPlayer state machine.
   */
  private async ensureAvPlayer(): Promise<media.AVPlayer> {
    if (this.avPlayer !== null) {
      return this.avPlayer;
    }

    const player = await media.createAVPlayer();
    player.on('stateChange', async (state: string) => {
      switch (state) {
        case 'initialized':
          await player.prepare();
          break;
        case 'prepared':
          await player.play();
          break;
        case 'completed':
          await this.syncAvSessionPlaybackState(false, 0);
          break;
        case 'error':
          console.error(`${TAG}: AVPlayer entered error state`);
          break;
        default:
          break;
      }
    });

    player.on('error', (error: BusinessError) => {
      console.error(`${TAG}: AVPlayer error code=${error.code}, message=${error.message}`);
    });

    this.avPlayer = player;
    return player;
  }

  /**
   * Lazily creates and activates the system AVSession for lock-screen and control-center controls.
   */
  private async ensureAvSession(): Promise<avSession.AVSession | null> {
    if (this.session !== null) {
      return this.session;
    }
    if (this.context === null) {
      return null;
    }

    const session = await avSession.createAVSession(this.context, 'AuraMusicSession', 'audio');
    session.on('play', () => {
      if (this.avPlayer !== null &&
        (this.avPlayer.state === 'paused' || this.avPlayer.state === 'prepared')) {
        this.avPlayer.play();
      }
    });
    session.on('pause', () => {
      if (this.avPlayer !== null && this.avPlayer.state === 'playing') {
        this.avPlayer.pause();
      }
    });
    session.on('stop', () => {
      if (this.avPlayer !== null) {
        this.avPlayer.stop();
      }
    });
    session.on('seek', (timeMs: number) => {
      if (this.avPlayer !== null) {
        this.avPlayer.seek(Math.max(0, timeMs), media.SeekMode.SEEK_CLOSEST);
      }
    });

    await session.activate();
    this.session = session;
    return session;
  }

  private async syncAvSessionMetadata(
    id: string,
    title: string,
    artist: string,
    album: string,
    durationSeconds: number,
  ): Promise<void> {
    if (this.session === null) {
      return;
    }
    const metadata: avSession.AVMetadata = {
      assetId: id.length > 0 ? id : 'aura_track',
      title: title,
      artist: artist,
      album: album,
      duration: Math.max(0, durationSeconds) * 1000,
    };
    await this.session.setAVMetadata(metadata);
  }

  private async syncAvSessionPlaybackState(
    isPlaying: boolean,
    positionSeconds: number,
  ): Promise<void> {
    if (this.session === null) {
      return;
    }
    const playbackState: avSession.AVPlaybackState = {
      state: isPlaying
        ? avSession.PlaybackState.PLAYBACK_STATE_PLAY
        : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: Math.max(0, positionSeconds) * 1000,
        updateTime: new Date().getTime(),
      },
    };
    await this.session.setAVPlaybackState(playbackState);
  }

  /**
   * Requests a continuous `audioPlayback` background task via backgroundTaskManager.
   */
  private async startBackgroundTask(): Promise<void> {
    if (this.isBackgroundRunning || this.context === null) {
      return;
    }

    const wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: this.context.abilityInfo?.bundleName ?? 'com.auramusic.app',
          abilityName: 'MainAbility',
        },
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
    };

    const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);
    await backgroundTaskManager.startBackgroundRunning(
      this.context,
      backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
      agent,
    );
    this.isBackgroundRunning = true;
  }

  private async stopBackgroundTask(): Promise<void> {
    if (!this.isBackgroundRunning || this.context === null) {
      return;
    }
    await backgroundTaskManager.stopBackgroundRunning(this.context);
    this.isBackgroundRunning = false;
  }

  /**
   * Stub for creating/destroying the `@ohos.window` desktop lyrics floating subWindow.
   * Requires `ohos.permission.SYSTEM_FLOAT_WINDOW` granted by the user.
   */
  private async toggleLyricsSubWindow(enabled: boolean, currentLyric: string): Promise<void> {
    if (currentLyric.length > 0) {
      AppStorage.setOrCreate('auraDesktopLyricLine', currentLyric);
    }

    if (!enabled) {
      if (this.lyricsSubWindow !== null) {
        await this.lyricsSubWindow.destroyWindow();
        this.lyricsSubWindow = null;
      }
      return;
    }

    if (this.lyricsSubWindow !== null || this.context === null) {
      return;
    }

    const config: window.Configuration = {
      name: OhosAudioPlugin.LYRICS_WINDOW_NAME,
      windowType: window.WindowType.TYPE_FLOAT,
      ctx: this.context,
    };
    const subWindow = await window.createWindow(config);
    await subWindow.resize(720, 140);
    await subWindow.moveWindowTo(60, 180);
    // Load the ArkUI desktop lyrics page when added under `resources/base/profile/main_pages.json`.
    await subWindow.setUIContent('pages/DesktopLyricsPage');
    await subWindow.showWindow();
    this.lyricsSubWindow = subWindow;
  }

  private releaseResources(): void {
    if (this.avPlayer !== null) {
      this.avPlayer.release();
      this.avPlayer = null;
    }
    if (this.session !== null) {
      this.session.destroy();
      this.session = null;
    }
    if (this.lyricsSubWindow !== null) {
      this.lyricsSubWindow.destroyWindow();
      this.lyricsSubWindow = null;
    }
    if (this.isBackgroundRunning && this.context !== null) {
      backgroundTaskManager.stopBackgroundRunning(this.context);
      this.isBackgroundRunning = false;
    }
  }

  private reportError(result: MethodResult, code: string, err: unknown): void {
    const businessErr = err as BusinessError;
    const message = businessErr?.message ?? String(err);
    console.error(`${TAG}: ${code} - ${message}`);
    result.error(code, message, null);
  }
}
