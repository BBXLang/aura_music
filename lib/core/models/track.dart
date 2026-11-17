import 'package:flutter/material.dart';

/// Represents an audio track in the AuraMusic library.
class Track {
  /// Creates an immutable [Track] instance.
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.quality,
    required this.sourceId,
    required this.durationSeconds,
    required this.colors,
    required this.lyrics,
    this.liked = false,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String quality;
  final String sourceId;
  final int durationSeconds;
  final List<Color> colors;
  final List<String> lyrics;
  final bool liked;

  /// Returns duration formatted as `mm:ss`.
  String get formattedDuration {
    final safeSeconds = durationSeconds < 0 ? 0 : durationSeconds;
    final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Returns a copy of this track with the specified fields replaced.
  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? quality,
    String? sourceId,
    int? durationSeconds,
    List<Color>? colors,
    List<String>? lyrics,
    bool? liked,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      quality: quality ?? this.quality,
      sourceId: sourceId ?? this.sourceId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      colors: colors ?? this.colors,
      lyrics: lyrics ?? this.lyrics,
      liked: liked ?? this.liked,
    );
  }
}

/// Built-in sample catalog of 16 rich tracks for AuraMusic.
const List<Track> sampleTracks = [
  Track(
    id: 'trk_01',
    title: '星云漫游',
    artist: '林屿森 / Aura Lab',
    album: '深空声景 Vol.1',
    quality: 'AudioVivid',
    sourceId: 'local',
    durationSeconds: 264,
    colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF38BDF8)],
    lyrics: ['穿过尘埃与微光', '星云在耳畔缓缓铺张', '失重的频率正在回响', '直到宇宙尽头仍未散场'],
    liked: true,
  ),
  Track(
    id: 'trk_02',
    title: '落日玻璃海',
    artist: '苏知夏',
    album: '海岸折射率',
    quality: 'Hi-Res',
    sourceId: 'netease',
    durationSeconds: 238,
    colors: [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFDE047)],
    lyrics: ['橘色潮汐漫过堤岸线', '玻璃海面映出你侧脸', '风把晚霞折成旧明信片', '我们在余晖里静止时间'],
    liked: true,
  ),
  Track(
    id: 'trk_03',
    title: '极光森林',
    artist: 'Nordic Echo',
    album: '北纬六十六度',
    quality: 'AudioVivid',
    sourceId: 'local',
    durationSeconds: 295,
    colors: [Color(0xFF064E3B), Color(0xFF10B981), Color(0xFF67E8F9)],
    lyrics: ['松针凝结第一缕寒霜', '绿色光幕在夜空轻轻晃', '鹿群踏过沉默的冰原', '听见大地深处脉搏跳响'],
  ),
  Track(
    id: 'trk_04',
    title: '午夜黄金律',
    artist: '周砚 / Velvet Jazz',
    album: '霓虹切分音',
    quality: 'SQ',
    sourceId: 'qq',
    durationSeconds: 214,
    colors: [Color(0xFF451A03), Color(0xFFD97706), Color(0xFFFEF08A)],
    lyrics: ['萨克斯在十二点整苏醒', '冰块撞击杯壁清脆回音', '街灯把影子拉成黄金比例', '今夜所有烦恼都暂停'],
    liked: true,
  ),
  Track(
    id: 'trk_05',
    title: '量子雨夜',
    artist: 'Kaito & Miu',
    album: '赛博梅雨季',
    quality: 'Hi-Res',
    sourceId: 'netease',
    durationSeconds: 247,
    colors: [Color(0xFF0F172A), Color(0xFF0284C7), Color(0xFFA855F7)],
    lyrics: ['霓虹倒映在积水路面', '雨滴坠落像二进制诗篇', '如果平行世界同时出现', '哪一个你会留在身边'],
  ),
  Track(
    id: 'trk_06',
    title: '银杏信笺',
    artist: '程安',
    album: '秋日慢板',
    quality: 'SQ',
    sourceId: 'local',
    durationSeconds: 203,
    colors: [Color(0xFF713F12), Color(0xFFEAB308), Color(0xFFFEF9C3)],
    lyrics: ['风吹落十月第一页金黄', '石板路尽头琴声正悠长', '把未寄出的句子折进书页', '等来年春天再拆封读响'],
  ),
  Track(
    id: 'trk_07',
    title: '深海回声',
    artist: 'Abyssal Choir',
    album: '马里亚纳',
    quality: 'AudioVivid',
    sourceId: 'apple',
    durationSeconds: 312,
    colors: [Color(0xFF082F49), Color(0xFF0369A1), Color(0xFF2DD4BF)],
    lyrics: ['潜入两千米幽蓝静谧', '鲸歌穿透层层水压传递', '荧光水母点亮无声海域', '心跳与洋流同频呼吸'],
  ),
  Track(
    id: 'trk_08',
    title: '白昼梦游者',
    artist: 'Luna Park',
    album: '失焦胶片',
    quality: 'HQ 320',
    sourceId: 'qq',
    durationSeconds: 196,
    colors: [Color(0xFF4C1D95), Color(0xFF8B5CF6), Color(0xFFF472B6)],
    lyrics: ['三点钟的咖啡馆飘着微甜', '云朵在窗外慢动作漂移', '不需要闹钟也不必赶时间', '做一场清醒的白日梦境'],
  ),
  Track(
    id: 'trk_09',
    title: '风过麦浪',
    artist: '沈清禾',
    album: '山野来信',
    quality: 'Hi-Res',
    sourceId: 'local',
    durationSeconds: 229,
    colors: [Color(0xFF365314), Color(0xFF84CC16), Color(0xFFFDE68A)],
    lyrics: ['远山轮廓融进薄雾晨光', '木吉他拨动田野的清香', '风吹过麦浪沙沙作响', '像童年外婆轻哼的歌谣'],
  ),
  Track(
    id: 'trk_10',
    title: '琥珀色黄昏',
    artist: '顾星河',
    album: '旧唱片店',
    quality: 'SQ',
    sourceId: 'netease',
    durationSeconds: 251,
    colors: [Color(0xFF78350F), Color(0xFFF59E0B), Color(0xFFFDA4AF)],
    lyrics: ['唱针落下微弱的沙沙声', '把整个傍晚封存进琥珀中', '黑胶旋转着记忆的年轮', '温柔得让人不想醒来'],
  ),
  Track(
    id: 'trk_11',
    title: '像素流星',
    artist: '8-Bit Dreamers',
    album: 'Arcade Night',
    quality: 'HQ 320',
    sourceId: 'qq',
    durationSeconds: 184,
    colors: [Color(0xFF311042), Color(0xFFDB2777), Color(0xFF22D3EE)],
    lyrics: ['闪烁屏幕亮起复古波纹', '八比特合成器划破夜深', '接住一颗像素化的流星', '存档所有热血与纯真'],
  ),
  Track(
    id: 'trk_12',
    title: '雪落长安',
    artist: '古风弦乐团',
    album: '十二时辰',
    quality: 'AudioVivid',
    sourceId: 'local',
    durationSeconds: 276,
    colors: [Color(0xFF1E293B), Color(0xFF64748B), Color(0xFFE2E8F0)],
    lyrics: ['朱雀门外飞雪轻叩红墙', '古筝与大提琴隔空对话', '灯笼映亮石阶上的微霜', '一曲终了岁月静静流淌'],
    liked: true,
  ),
  Track(
    id: 'trk_13',
    title: '潮汐引力',
    artist: 'Tide & Orbit',
    album: '双星系统',
    quality: 'Hi-Res',
    sourceId: 'apple',
    durationSeconds: 242,
    colors: [Color(0xFF134E4A), Color(0xFF0D9488), Color(0xFF93C5FD)],
    lyrics: ['月亮在三十八万公里外', '牵引着每一寸温柔波澜', '我们像两颗互绕的行星', '保持距离却从未走散'],
  ),
  Track(
    id: 'trk_14',
    title: '城市天台',
    artist: '陈默',
    album: '晚风频道',
    quality: 'SQ',
    sourceId: 'netease',
    durationSeconds: 219,
    colors: [Color(0xFF1E1B4B), Color(0xFF6366F1), Color(0xFFFB7185)],
    lyrics: ['高架桥车流汇成光之河', '天台的风吹散白天的喧嚣', '耳机里正循环最爱的歌', '整座城市都是我的背景'],
  ),
  Track(
    id: 'trk_15',
    title: '月光变奏曲',
    artist: 'Clara Lin',
    album: '夜曲手稿',
    quality: 'Hi-Res',
    sourceId: 'local',
    durationSeconds: 288,
    colors: [Color(0xFF0F172A), Color(0xFF3B82F6), Color(0xFFCBD5E1)],
    lyrics: ['黑白琴键流淌银色月光', '左手低音像沉睡的海洋', '八度跳跃在指尖轻轻绽放', '夜色也因此变得透明清亮'],
  ),
  Track(
    id: 'trk_16',
    title: '晨曦微澜',
    artist: 'Aura Acoustic',
    album: '日出之前',
    quality: 'AudioVivid',
    sourceId: 'local',
    durationSeconds: 207,
    colors: [Color(0xFF431407), Color(0xFFFB923C), Color(0xFFBAE6FD)],
    lyrics: ['天边泛起第一抹鱼肚白', '露珠在草叶上微微摇摆', '新的一天正随旋律醒来', '万物都在光里自由舒展'],
  ),
];
