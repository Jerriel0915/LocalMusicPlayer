/**
 * 歌单详情页面
 * 显示歌单信息和歌曲列表
 */

import { router } from '@kit.ArkUI';
import { TrackInfo } from '../models/TrackInfo';
import { PlayList } from '../models/PlayList';
import { Database } from '../services/Database';
import { AudioSvc } from '../services/AudioSvc';
import { TrackItem } from '../views/TrackItem';
import { MiniPlayer } from '../views/MiniPlayer';
import { image } from '@kit.ImageKit';
import { CoverExtractor } from '../utils/CoverExtractor';

@Entry
@Component
struct PlaylistDetailPage {
  @State private playlist: PlayList | null = null;
  @State private tracks: TrackInfo[] = [];
  @State private isLoading: boolean = true;
  @State private currentTrackId: number = -1;
  @State private playlistId: number = -1;
  @State private coverPixelMap: image.PixelMap | null = null;

  private database: Database = Database.getInstance();
  private audioSvc: AudioSvc = AudioSvc.getInstance();

  aboutToAppear() {
    // 获取传入的歌单 ID
    const params = router.getParams() as Record<string, number>;
    if (params && params.playlistId) {
      this.playlistId = params.playlistId;
    }
    this.loadPlaylistData();
  }
  
  onPageShow() {
    // 页面显示时刷新数据（从添加歌曲页面返回时）
    this.loadPlaylistData();
  }

  private async loadPlaylistData() {
    if (this.playlistId < 0) {
      this.isLoading = false;
      return;
    }

    try {
      this.isLoading = true;
      
      // 获取歌单信息
      const playlists = await this.database.getAllPlaylists();
      this.playlist = playlists.find((p: PlayList): boolean => p.id === this.playlistId) || null;
      
      // 获取歌单中的歌曲
      if (this.playlist) {
        this.tracks = await this.database.getPlaylistTracks(this.playlist.id);
        
        // 加载封面：优先使用歌单封面，否则使用第一首歌的封面
        if (this.playlist.coverUri) {
          // 歌单有自定义封面
          // TODO: 加载自定义封面
        } else if (this.tracks.length > 0 && this.tracks[0].filePath) {
          // 使用第一首歌的封面
          const firstTrack = this.tracks[0];
          const cachedCover = CoverExtractor.getCachedCover(firstTrack.filePath);
          if (cachedCover) {
            this.coverPixelMap = cachedCover;
          } else {
            try {
              const metadata = await CoverExtractor.extractMetadata(firstTrack.filePath);
              if (metadata.cover) {
                this.coverPixelMap = metadata.cover;
              }
            } catch (err) {
              console.error('加载封面失败:', err);
            }
          }
        }
      }
      
      // 获取当前播放的歌曲
      const currentTrack = this.audioSvc.getCurrentTrack();
      if (currentTrack) {
        this.currentTrackId = currentTrack.id;
      }
    } catch (err) {
      console.error('加载歌单数据失败:', err);
    } finally {
      this.isLoading = false;
    }
  }

  private playTrack(track: TrackInfo) {
    console.info(`准备播放: ${track.title}`);
    
    // 找到点击歌曲在列表中的索引
    const trackIndex = this.tracks.findIndex(t => t.id === track.id);
    
    // 设置播放队列并播放
    this.audioSvc.setPlayQueue(this.tracks, trackIndex >= 0 ? trackIndex : 0);
    
    this.currentTrackId = track.id;
  }

  private async navigateBack() {
    try {
      await router.back();
    } catch (err) {
      console.error('返回失败:', err);
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Image($r('app.media.icon_back'))
            .width(24)
            .height(24)
            .fillColor('#333333')
        }
        .type(ButtonType.Circle)
        .backgroundColor('transparent')
        .width(44)
        .height(44)
        .onClick((): void => { this.navigateBack(); })

        Text('歌单详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(44).height(44)
      }
      .width('100%')
      .height(80)
      .padding({ left: 8, right: 8, top: 30 })
      .backgroundColor('#FFFFFF')

      // 歌单信息区域
      Column() {
        Row() {
          // 封面
          if (this.coverPixelMap) {
            Image(this.coverPixelMap)
              .width(100)
              .height(100)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              Image($r('app.media.play_list'))
                .width(48)
                .height(48)
                .fillColor('#CCCCCC')
            }
            .width(100)
            .height(100)
            .backgroundColor('#F0F0F0')
            .borderRadius(8)
            .justifyContent(FlexAlign.Center)
          }

          // 歌单名称和描述
          Column() {
            Text(this.playlist?.name || '未知歌单')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')

            Text(this.playlist?.description || '暂无描述')
              .fontSize(13)
              .fontColor('#999999')
              .margin({ top: 8 })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')

            Text(`${this.tracks.length} 首歌曲`)
              .fontSize(12)
              .fontColor('#CCCCCC')
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 16 })
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .backgroundColor('#FFFFFF')

      // 歌曲列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.tracks.length === 0) {
        Column() {
          Image($r('app.media.icon_music_note'))
            .width(80)
            .height(80)
            .fillColor('#CCCCCC')
            .margin({ bottom: 16 })

          Text('暂无歌曲')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ bottom: 16 })

          Button('添加歌曲')
            .width(120)
            .height(40)
            .backgroundColor('#FF4081')
            .fontColor('#FFFFFF')
            .borderRadius(20)
            .onClick(async () => {
              try {
                await router.pushUrl({
                  url: 'pages/AddToPlaylist',
                  params: {
                    playlistId: this.playlistId,
                    playlistName: this.playlist?.name || ''
                  }
                });
              } catch (err) {
                console.error('跳转失败:', err);
              }
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Stack({ alignContent: Alignment.TopStart }) {
          List({ space: 0 }) {
            ForEach(this.tracks, (track: TrackInfo, index: number) => {
              ListItem() {
                TrackItem({
                  track: track,
                  index: -1,
                  isPlaying: this.currentTrackId === track.id,
                  onTrackClick: (t: TrackInfo): void => { this.playTrack(t); }
                })
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: '#EEEEEE' })
          .padding({ bottom: 64 })

          // 悬浮添加按钮
          Button() {
            Image($r('app.media.icon_favorite'))
              .width(28)
              .height(28)
              .fillColor('#FFFFFF')
          }
          .width(56)
          .height(56)
          .backgroundColor('#FF4081')
          .borderRadius(28)
          .position({ x: '100%', y: '100%' })
          .translate({ x: -72, y: -136 })
          .shadow({ radius: 8, color: 'rgba(255,64,129,0.3)' })
          .onClick(async () => {
            try {
              await router.pushUrl({
                url: 'pages/AddToPlaylist',
                params: {
                  playlistId: this.playlistId,
                  playlistName: this.playlist?.name || ''
                }
              });
            } catch (err) {
              console.error('跳转失败:', err);
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
      }

      // 迷你播放条
      Column() {
        MiniPlayer({
          onExpand: (): void => {
            router.pushUrl({ url: 'pages/Player' });
          }
        })
      }
      .width('100%')
      .position({ bottom: 0 })
      .zIndex(100)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
