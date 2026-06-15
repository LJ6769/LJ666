// 首页与直播列表占位数据（未接库前的演示）。
import '../models/home_models.dart';

/// 占位数据，接入数据库后替换为仓库/接口层返回。
const HomeFeedData kHomePlaceholderData = HomeFeedData(
  coinBalance: 0,
  profileStories: [
    ProfileStory(id: '1', name: 'User 1'),
    ProfileStory(id: '2', name: 'User 2'),
    ProfileStory(id: '3', name: 'User 3'),
    ProfileStory(id: '4', name: 'User 4'),
    ProfileStory(id: '5', name: 'User 5'),
    ProfileStory(id: '6', name: 'User 6'),
    ProfileStory(id: '7', name: 'User 7'),
    ProfileStory(id: '8', name: 'User 8'),
  ],
  liveRooms: [
    LiveRoom(
      id: 'live-1',
      hostName: 'Crystal',
      hostHandle: '@87654efr',
      title: 'Professional Bartender Mixing Live Online...',
    ),
    LiveRoom(
      id: 'live-2',
      hostName: 'Alex',
      hostHandle: '@user_handle',
      title: 'The Cloud Bar: Live Mixology Session...',
    ),
    LiveRoom(
      id: 'live-3',
      hostName: 'Mia',
      hostHandle: '@mia_mix',
      title: 'Classic Cocktail Techniques Unlocked...',
    ),
    LiveRoom(
      id: 'live-4',
      hostName: 'Leo',
      hostHandle: '@leo_bar',
      title: 'Signature Drinks for Home Bartenders...',
    ),
    LiveRoom(
      id: 'live-5',
      hostName: 'Nora',
      hostHandle: '@nora_pour',
      title: 'Whiskey Tasting & Pairing Live...',
    ),
    LiveRoom(
      id: 'live-6',
      hostName: 'Sam',
      hostHandle: '@sam_shake',
      title: 'Shaker Skills: From Basics to Pro...',
    ),
  ],
  tipsyBarRooms: [
    TipsyBarRoom(
      id: 'bar-1',
      title: 'Neon Tavern',
      description: 'Our online tavern is now open...',
      participantAvatarUrls: [null, null, null, null],
      imageOnRight: false,
    ),
    TipsyBarRoom(
      id: 'bar-2',
      title: 'Cocktail Inspiration Exchange',
      description: 'Share your recipes for visually stunning cocktails...',
      participantAvatarUrls: [null, null, null, null],
      imageOnRight: true,
    ),
    TipsyBarRoom(
      id: 'bar-3',
      title: 'Retro Bar Mixology',
      description: 'Experience the allure of a vintage bar counter...',
      participantAvatarUrls: [null, null, null, null],
      imageOnRight: false,
    ),
    TipsyBarRoom(
      id: 'bar-4',
      title: 'Healing Mixology Workshop',
      description: 'Let a beautifully layered cocktail soothe your day...',
      participantAvatarUrls: [null, null, null, null],
      imageOnRight: true,
    ),
    TipsyBarRoom(
      id: 'bar-5',
      title: 'Shaking Masterclass',
      description: 'Master standard shaking techniques...',
      participantAvatarUrls: [null, null, null, null],
      imageOnRight: false,
    ),
    TipsyBarRoom(
      id: 'bar-6',
      title: 'Bartender Salon',
      description: 'Discuss professional bartending etiquette...',
      participantAvatarUrls: [null, null, null, null],
      imageOnRight: true,
    ),
  ],
);

/// Bartending Live 列表页占位（See All / Popular 随机池）。
const List<LiveRoom> kBartendingLiveListPlaceholder = [
  LiveRoom(
    id: 'live-t1',
    categorySlug: 'tutorials',
    hostName: 'Crystal',
    hostHandle: '@87654efr',
    title:
        'Professional Bartender Mixing Live Online: Deconstructing Classic Recipes + Teaching Creative Signature Cocktails.',
  ),
  LiveRoom(
    id: 'live-t2',
    categorySlug: 'tutorials',
    hostName: 'Alice',
    hostHandle: '@user_handle',
    title:
        'The Cloud Bar: Live Mixology Session — A Bartender with 10 Years of Experience Guides You in Unlocking the Perfect Drink.',
  ),
  LiveRoom(
    id: 'live-t3',
    categorySlug: 'tutorials',
    hostName: 'Mia',
    hostHandle: '@mia_mix',
    title: 'Classic Cocktail Techniques Unlocked...',
  ),
  LiveRoom(
    id: 'live-o1',
    categorySlug: 'other',
    hostName: 'Leo',
    hostHandle: '@leo_bar',
    title: 'Signature Drinks for Home Bartenders...',
  ),
  LiveRoom(
    id: 'live-o2',
    categorySlug: 'other',
    hostName: 'Nora',
    hostHandle: '@nora_pour',
    title: 'Whiskey Tasting & Pairing Live...',
  ),
  LiveRoom(
    id: 'live-o3',
    categorySlug: 'other',
    hostName: 'Sam',
    hostHandle: '@sam_shake',
    title: 'Shaker Skills: From Basics to Pro...',
  ),
  LiveRoom(
    id: 'live-t4',
    categorySlug: 'tutorials',
    hostName: 'Jade',
    hostHandle: '@jade_pour',
    title: 'Summer Spritz & Light Cocktails...',
  ),
  LiveRoom(
    id: 'live-o4',
    categorySlug: 'other',
    hostName: 'Finn',
    hostHandle: '@finn_mix',
    title: 'Bar Tools 101: What You Really Need...',
  ),
];
