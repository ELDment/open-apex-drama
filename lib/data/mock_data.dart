import 'package:flutter/material.dart';

import '../models/drama.dart';
import '../models/drama_category.dart';
import '../models/membership_plan.dart';
import '../models/watch_record.dart';

/// All data in this file is hard coded on purpose: this phase only builds the
/// static UI shell, no API, no player logic and no persistence.
const Drama _flashMarriage = Drama(
  id: 'flash-marriage',
  title: '闪婚老公是财阀',
  kind: '短剧',
  category: '都市',
  tags: <String>['甜宠', '逆袭'],
  episodes: 80,
  rating: 9.4,
  viewers: '100.1万',
  description: '一场意外的闪婚，让平凡女孩遇上了神秘财阀总裁。原本只想互相扶持的两个人，在一次次风波里慢慢靠近，开启高甜人生…',
  coverColors: <Color>[Color(0xFF6E3B36), Color(0xFFB5654A), Color(0xFF2A1310)],
  episodeTitles: <String>['意外闪婚', '我不想再错过你了', '财阀的秘密'],
  badge: '热播',
);

const Drama _rebirth = Drama(
  id: 'rebirth-comeback',
  title: '重生之逆风翻盘',
  kind: '短剧',
  category: '都市',
  tags: <String>['逆袭', '热血'],
  episodes: 80,
  rating: 9.2,
  viewers: '98.3万',
  description: '重生归来，改变人生轨迹，这一次她要把失去的全部拿回来。',
  coverColors: <Color>[Color(0xFF2E4A52), Color(0xFF5F8C8B), Color(0xFF15282C)],
  episodeTitles: <String>['命运重启', '棋局初开', '逆风而上'],
);

const Drama _failedLove = Drama(
  id: 'failed-love',
  title: '不如热恋的我们',
  kind: '短剧',
  category: '都市',
  tags: <String>['甜宠', '家庭'],
  episodes: 82,
  rating: 9.0,
  viewers: '82.7万',
  description: '分开多年后重逢，他们才发现心动从未停止。',
  coverColors: <Color>[Color(0xFF6E4468), Color(0xFFB0799A), Color(0xFF34203A)],
  episodeTitles: <String>['久别', '假装陌生', '心动重来'],
);

const Drama _princess = Drama(
  id: 'princess-crossing',
  title: '穿越之王妃有点拽',
  kind: '短剧',
  category: '古装',
  tags: <String>['穿越', '甜宠'],
  episodes: 78,
  rating: 9.1,
  viewers: '76.5万',
  description: '现代女孩意外穿越古代，成了人人避之不及的王妃。',
  coverColors: <Color>[Color(0xFF7A4A2C), Color(0xFFC98B5C), Color(0xFF2A1A12)],
  episodeTitles: <String>['初入王府', '王爷别闹', '这一世我罩你'],
);

const Drama _hiddenIdentity = Drama(
  id: 'hidden-identity',
  title: '夫人你马甲掉了',
  kind: '短剧',
  category: '都市',
  tags: <String>['甜宠', '逆袭'],
  episodes: 83,
  rating: 9.3,
  viewers: '88.2万',
  description: '隐藏身份的她，闪婚后被宠成全网羡慕的夫人。',
  coverColors: <Color>[Color(0xFF463A69), Color(0xFF8B7BB5), Color(0xFF221C36)],
  episodeTitles: <String>['马甲初现', '夫人又掉马了', '全网都在磕'],
  badge: '甜宠',
);

const Drama _contractBride = Drama(
  id: 'contract-bride',
  title: '总裁的契约新娘',
  kind: '短剧',
  category: '都市',
  tags: <String>['甜宠', '家庭'],
  episodes: 90,
  rating: 8.9,
  viewers: '64.8万',
  description: '一纸契约，把两个陌生人绑在了一起。',
  coverColors: <Color>[Color(0xFF7A2F3A), Color(0xFFC15C64), Color(0xFF33141A)],
  episodeTitles: <String>['契约开始', '假戏真做', '心动成真'],
);

const Drama _eighties = Drama(
  id: 'eighties-space',
  title: '重生八零：她靠空间养崽崽',
  kind: '短剧',
  category: '年代',
  tags: <String>['家庭', '逆袭'],
  episodes: 100,
  rating: 9.0,
  viewers: '59.3万',
  description: '带着空间回到八零年代，她决定把日子过成诗。',
  coverColors: <Color>[Color(0xFF3A4A38), Color(0xFF7D9A74), Color(0xFF1B261A)],
  episodeTitles: <String>['重回八零', '空间初醒', '日子有盼头'],
);

const Drama _changan = Drama(
  id: 'changan-coroner',
  title: '长安第一女仵作',
  kind: '电视剧',
  category: '古装',
  tags: <String>['悬疑', '穿越'],
  episodes: 88,
  rating: 9.2,
  viewers: '48.6万',
  description: '大唐长安，一具无名尸牵出惊天迷局。',
  coverColors: <Color>[Color(0xFF8A5A2A), Color(0xFFD0A35D), Color(0xFF3A2410)],
  episodeTitles: <String>['雨夜奇案', '长安暗涌', '真相将至'],
  badge: '口碑',
);

const Drama _night = Drama(
  id: 'night-sinking',
  title: '夜色沉沦',
  kind: '电视剧',
  category: '都市',
  tags: <String>['悬疑', '虐恋'],
  episodes: 72,
  rating: 8.8,
  viewers: '41.2万',
  description: '一场夜雨，让两个秘密缠身的人再次相遇。',
  coverColors: <Color>[Color(0xFF2F3F5C), Color(0xFF6A84A8), Color(0xFF16202E)],
  episodeTitles: <String>['雨夜重逢', '秘密边缘', '无法回头'],
);

const Drama _heartbeat = Drama(
  id: 'heartbeat-signal',
  title: '她的心动信号',
  kind: '电影',
  category: '爱情',
  tags: <String>['甜宠', '家庭'],
  episodes: 110,
  rating: 8.7,
  viewers: '36.4万',
  description: '夏日海边，两个年轻人错过了整个青春。',
  coverColors: <Color>[Color(0xFF5C2C46), Color(0xFFA05C7A), Color(0xFF2A1320)],
  episodeTitles: <String>['夏天的海', '心动信号', '迟到的答案'],
);

const Drama _bodyguard = Drama(
  id: 'female-bodyguard',
  title: '我的贴身女保镖',
  kind: '短剧',
  category: '动作',
  tags: <String>['热血', '都市'],
  episodes: 74,
  rating: 9.1,
  viewers: '70.5万',
  description: '王牌保镖遇上傲娇少爷，鸡飞狗跳的守护日常。',
  coverColors: <Color>[Color(0xFF3B3B44), Color(0xFF80808E), Color(0xFF1A1A20)],
  episodeTitles: <String>['贴身保护', '别靠太近', '少爷别跑'],
);

const Drama _medicalConsort = Drama(
  id: 'medical-consort',
  title: '绝世医妃不好惹',
  kind: '短剧',
  category: '古装',
  tags: <String>['穿越', '甜宠'],
  episodes: 92,
  rating: 9.2,
  viewers: '58.9万',
  description: '现代神医穿成落魄王妃，一手银针救夫君，也救自己。',
  coverColors: <Color>[Color(0xFF4A2F55), Color(0xFF9A6E93), Color(0xFF20132A)],
  episodeTitles: <String>['王妃醒醒', '银针救人', '医妃很忙'],
  badge: '新剧',
);

const List<Drama> mockDramas = <Drama>[
  _flashMarriage,
  _rebirth,
  _failedLove,
  _princess,
  _hiddenIdentity,
  _contractBride,
  _eighties,
  _changan,
  _night,
  _heartbeat,
  _bodyguard,
  _medicalConsort,
];

/// Banner carousel on the home tab.
const List<Drama> mockFeatured = <Drama>[_flashMarriage, _rebirth, _princess];

final Drama mockHero = mockFeatured.first;

/// Small horizontal rail at the bottom of the home tab.
const List<Drama> mockRecentUpdates = <Drama>[
  _medicalConsort,
  _hiddenIdentity,
  _changan,
  _rebirth,
  _heartbeat,
  _eighties,
];

/// 追剧 → 收藏.
const List<Drama> mockFavorites = <Drama>[
  _rebirth,
  _failedLove,
  _princess,
  _hiddenIdentity,
  _changan,
  _medicalConsort,
];

const DramaCategory _cityCategory = DramaCategory(
  name: '都市',
  displayCount: 236,
  coverColors: <Color>[Color(0xFF3B2B32), Color(0xFF8C5A5F), Color(0xFF181015)],
  matchTags: <String>['都市'],
);

/// Browse categories on the 分类 tab.
const List<DramaCategory> mockCategories = <DramaCategory>[
  _cityCategory,
  DramaCategory(
    name: '古装',
    displayCount: 198,
    coverColors: <Color>[
      Color(0xFF4A3820),
      Color(0xFFB08A55),
      Color(0xFF1D150C),
    ],
  ),
  DramaCategory(
    name: '现言',
    displayCount: 215,
    coverColors: <Color>[
      Color(0xFF4C2F3D),
      Color(0xFFA87386),
      Color(0xFF1F1218),
    ],
    matchTags: <String>['甜宠', '爱情'],
  ),
  DramaCategory(
    name: '悬疑',
    displayCount: 127,
    coverColors: <Color>[
      Color(0xFF23313D),
      Color(0xFF5C7182),
      Color(0xFF111820),
    ],
    matchTags: <String>['悬疑'],
  ),
  DramaCategory(
    name: '热血',
    displayCount: 143,
    coverColors: <Color>[
      Color(0xFF3A2A2A),
      Color(0xFF8E5B4C),
      Color(0xFF191010),
    ],
    matchTags: <String>['热血'],
  ),
  DramaCategory(
    name: '家庭',
    displayCount: 109,
    coverColors: <Color>[
      Color(0xFF3F3B28),
      Color(0xFF8F8A5E),
      Color(0xFF1A1910),
    ],
    matchTags: <String>['家庭'],
  ),
  DramaCategory(
    name: '逆袭',
    displayCount: 186,
    coverColors: <Color>[
      Color(0xFF283B3A),
      Color(0xFF5E8B84),
      Color(0xFF101A19),
    ],
    matchTags: <String>['逆袭'],
  ),
  DramaCategory(
    name: '甜宠',
    displayCount: 254,
    coverColors: <Color>[
      Color(0xFF5A2E3F),
      Color(0xFFC47E95),
      Color(0xFF25101A),
    ],
    matchTags: <String>['甜宠'],
  ),
  DramaCategory(
    name: '穿越',
    displayCount: 96,
    coverColors: <Color>[
      Color(0xFF2F2A4C),
      Color(0xFF7469A8),
      Color(0xFF14122A),
    ],
    matchTags: <String>['穿越'],
  ),
  DramaCategory(
    name: '年代',
    displayCount: 78,
    coverColors: <Color>[
      Color(0xFF343A28),
      Color(0xFF7C8A5A),
      Color(0xFF161A10),
    ],
    matchTags: <String>['年代'],
  ),
  DramaCategory(
    name: '动作',
    displayCount: 64,
    coverColors: <Color>[
      Color(0xFF2C2C33),
      Color(0xFF6F6F7C),
      Color(0xFF131316),
    ],
    matchTags: <String>['动作'],
  ),
  DramaCategory(
    name: '爱情',
    displayCount: 132,
    coverColors: <Color>[
      Color(0xFF4C2430),
      Color(0xFFA85B6C),
      Color(0xFF1F0D12),
    ],
    matchTags: <String>['爱情'],
  ),
];

/// Categories selected by the top filter chips before "更多" is expanded.
const int mockCategoryFilterCount = 8;


const List<WatchRecord> mockWatchHistory = <WatchRecord>[
  WatchRecord(drama: _flashMarriage, progress: 0.15, lastEpisode: 12),
  WatchRecord(drama: _rebirth, progress: 0.46, lastEpisode: 37),
  WatchRecord(drama: _princess, progress: 0.32, lastEpisode: 25),
];

/// The "继续观看" card at the top of the 追剧 tab.
const WatchRecord mockContinueWatching = WatchRecord(
  drama: _flashMarriage,
  progress: 0.15,
  lastEpisode: 12,
);

const List<MembershipPlan> mockMembershipPlans = <MembershipPlan>[
  MembershipPlan(
    name: '月会员',
    price: '18',
    originalPrice: '30',
    period: '连续包月',
    recommended: true,
  ),
  MembershipPlan(name: '季会员', price: '48', originalPrice: '90', period: '连续包季'),
  MembershipPlan(
    name: '年会员',
    price: '168',
    originalPrice: '380',
    period: '连续包年',
  ),
];

