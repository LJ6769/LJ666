-- >>> 20260603000002_six_tables_seed.sql
-- 由 generate_six_tables_seed.py 生成
-- 素材: /Users/mac/Downloads/Hilmi切图/Hilmi素材

truncate table public."Message" cascade;
truncate table public."LiveChat" cascade;
truncate table public."PostChat" cascade;
truncate table public."Post" cascade;
truncate table public."Live" cascade;
truncate table public."User" cascade;

-- User
insert into public."User" (display_name, gender, bio, avatar_path, is_popular_star, popular_star_sort, coins) values
  ('Caspian', 'male'::public.gender_type, $txt1$A whiskey beginner; enjoys sipping slowly and chatting.$txt1$, 'users/male/07f60db48311389623c311d669e0d216.jpg', false, null, 0),
  ('Orion', 'male'::public.gender_type, $txt2$Loves watching flair bartending; occasionally shakes up a few simple drinks himself.$txt2$, 'users/male/124f3dabc51b00b83fb23397614b5bc7_副本.jpg', false, null, 0),
  ('Soren', 'male'::public.gender_type, $txt3$Prefers hard spirits and classic cocktails; not a fan of anything too flashy or gimmicky.$txt3$, 'users/male/2fa39d58e44804f66932129b5eb3fb72.jpg', false, null, 0),
  ('Atticus', 'male'::public.gender_type, $txt4$Loves learning the stories behind the spirits—savoring the drink rather than downing it fast.$txt4$, 'users/male/5ea033948e9cbafbcb4ea221efd6b121.jpg', false, null, 0),
  ('Kael', 'male'::public.gender_type, $txt5$An at-home cocktail enthusiast; doesn't have many tools, but has enough to get the job done.$txt5$, 'users/male/66b7ef7a002cbf00727f86d3b49e7e02.jpg', false, null, 0),
  ('Thorne', 'male'::public.gender_type, $txt6$A craft beer aficionado; loves exploring a wide variety of flavors.$txt6$, 'users/male/6b475a7771285bad4fc004d7b322c741.jpg', false, null, 0),
  ('Evander', 'male'::public.gender_type, $txt7$Occasionally meets up with friends for a casual drink—relaxing conversation, strictly no work talk.$txt7$, 'users/male/6f6fa79bea0e6ac662a5a5ce9efdae1d.jpg', false, null, 0),
  ('Jasper', 'male'::public.gender_type, $txt8$Enjoys making simple cocktails at home using fresh fruit.$txt8$, 'users/male/8a0d4b91252652b65af9deb24ba37aeb.jpg', false, null, 0),
  ('Marlow', 'male'::public.gender_type, $txt9$A regular in late-night voice chat rooms—sipping a drink while chatting about daily life.$txt9$, 'users/male/96c90bfae9c8fbdf230fee6fafea2319.jpg', false, null, 0),
  ('Rohan', 'male'::public.gender_type, $txt10$Loves Asian-inspired cocktails; finds the aromatic spices truly captivating.$txt10$, 'users/male/a07b840e2e32c924b3169ec4571c0e16.jpg', false, null, 0),
  ('Silas', 'male'::public.gender_type, $txt11$Collects various types of small drinking glasses—believes that drinking should always be a ritual.$txt11$, 'users/male/a0aeb81442942abbb9a588d2eb65d880.jpg', false, null, 0),
  ('Torin', 'male'::public.gender_type, $txt12$Drinks responsibly—enjoys the pleasant buzz of being tipsy without aiming to get drunk.$txt12$, 'users/male/c6140e4b00f258dafac4b846a4342c43.jpg', false, null, 0),
  ('Uriah', 'male'::public.gender_type, $txt13$I also love non-alcoholic mocktails—delicious and guilt-free.$txt13$, 'users/male/ec66007c6f056c6ae339e3e60186e63c_副本.jpg', false, null, 0),
  ('Viggo', 'male'::public.gender_type, $txt14$My style is minimalist mixology; clean and refreshing is what matters most.$txt14$, 'users/male/eda68f142bd9cf77aab21cb892736c28.jpg', false, null, 0),
  ('Zane', 'male'::public.gender_type, $txt15$I learn mixology by following live streams—it’s a fun way to entertain myself at home every day.$txt15$, 'users/male/efdf90cde9925c0fe24a0bad17e66ac9.jpg', false, null, 0),
  ('Elowen', 'female'::public.gender_type, $txt16$Enjoys a light drink; occasionally mixes simple cocktails at home.$txt16$, 'users/female/592852497ab6e4fb1b80fbf427b30d18.jpg', true, 1, 0),
  ('Liora', 'female'::public.gender_type, $txt17$A connoisseur of the "tipsy glow"; loves a good atmosphere and beautiful glassware.$txt17$, 'users/female/60955dacc25e0ee6abbb57897bb29c8a.jpg', true, 2, 0),
  ('Marnie', 'female'::public.gender_type, $txt18$Enjoys a post-get off work drink to unwind and shake off the day's fatigue.$txt18$, 'users/female/692f79eeb66d16255f8faefa292baa5d.jpg', true, 3, 0),
  ('Ione', 'female'::public.gender_type, $txt19$Prefers crisp, fruity cocktails; has a low tolerance but loves trying new flavors.$txt19$, 'users/female/72564814ba8a88dd10504045df770ceb.jpg', true, 4, 0),
  ('Seraphina', 'female'::public.gender_type, $txt20$Occasionally explores new bars, documenting the recipes for delicious signature drinks.$txt20$, 'users/female/748d2481d5adf63d40a5dbc1254c73e1.jpg', true, 5, 0),
  ('Briar', 'female'::public.gender_type, $txt21$Loves small gatherings with friends—drinking and chatting makes for a perfectly cozy time.$txt21$, 'users/female/8e0d25662a646f0e8d4c438f8fa17c02.jpg', true, 6, 0),
  ('Paloma', 'female'::public.gender_type, $txt22$A devoted tequila fan; prefers signature cocktails with a sweet-and-sour profile.$txt22$, 'users/female/b612e5d024003574d534212acae68154.jpg', true, 7, 0),
  ('Soraya', 'female'::public.gender_type, $txt23$Prefers gentle, low-alcohol drinks; a mild buzz is just right.$txt23$, 'users/female/c078fc8dd99746ad50da8dd9ecc72c18.jpg', true, 8, 0),
  ('Wren', 'female'::public.gender_type, $txt24$A cocktail-mixing novice, slowly learning the ropes with simple recipes.$txt24$, 'users/female/d54ba3d44201befb31414b7c1d4d1200.jpg', true, 9, 0),
  ('Odette', 'female'::public.gender_type, $txt25$Prefers classic cocktails; not a fan of overly flashy or complicated combinations.$txt25$, 'users/female/dedb1d91321d4ec91864e8ee955d2063.jpg', true, 10, 0),
  ('Kaelin', 'female'::public.gender_type, $txt26$Loves watching live cocktail-mixing streams and tries to recreate the drinks herself.$txt26$, 'users/female/e3b808af0548772f85191b5a3c41dd21.jpg', false, null, 0),
  ('Zora', 'female'::public.gender_type, $txt27$Enjoys seeking out drinks that are visually stunning and "Instagrammable."$txt27$, 'users/female/e6d2ebea91fd3fc65d54f96e9e977e6f.jpg', false, null, 0),
  ('Lilibeth', 'female'::public.gender_type, $txt28$A lover of sweet drinks; steers clear of anything too bitter or too strong.$txt28$, 'users/female/f0c06ad77f3c9113c37786ef36c8337a.jpg', false, null, 0),
  ('Nova', 'female'::public.gender_type, $txt29$Loves experimenting with new recipes—often stumbles upon delightful surprises through trial and error.$txt29$, 'users/female/f3d679452276a14062960dac46f7dca2.jpg', false, null, 0),
  ('Thalassa', 'female'::public.gender_type, $txt30$The beach + a mild buzz = my ideal weekend combination.$txt30$, 'users/female/f9f491005a328da0b84059e31ffbf4e1.jpg', false, null, 0);

create temp table _user_rn on commit drop as
select id, row_number() over (order by created_at, id) as rn from public."User";


-- Live
insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'other', 'Other', 2, true,
  (select id from _user_rn where rn = 1),
  1, $txt31$Time to crack open a craft beer! An in-depth tasting session focused on Red Ales—sample brews and discuss flavor profiles online, chatting about great beer with fellow enthusiasts.$txt31$, array['#CraftBeer', '#BeerTasting', '#RedAle', '#BeerBuddies', '#CraftBeerSession'],
  'live-streams/other/1/cover.jpg', 'live-streams/other/1/video.mp4',
  19, true, 1
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'other', 'Other', 2, true,
  (select id from _user_rn where rn = 2),
  2, $txt32$A late-night, tipsy bartending soirée! Create the perfect vibe with home-mixed cocktails—let a good drink be the cure for a long, tiring day.$txt32$, array['#LateNightDrinks', '#HomeTipsy', '#RelaxedBartending', '#SocialDrinking', '#AtmosphericCocktails'],
  'live-streams/other/2/cover.jpg', 'live-streams/other/2/video.mp4',
  23, true, 2
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'other', 'Other', 2, true,
  (select id from _user_rn where rn = 3),
  3, $txt33$A special session dedicated to Japanese Whisky cocktails! Featuring premium base spirits like Yamazaki and Hakushu, we unlock the authentic charm of Japanese-style mixology.$txt33$, array['#JapaneseBartending', '#Whisky', '#YamazakiHakushu', '#PremiumCocktails', '#JapaneseMixology'],
  'live-streams/other/3/cover.jpg', 'live-streams/other/3/video.mp4',
  28, true, 3
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'tutorials', 'Tutorials', 1, true,
  (select id from _user_rn where rn = 4),
  1, $txt34$A wall-to-wall cabinet stocked with a thousand base spirits! Professional bartenders mix live online, offering step-by-step tutorials ranging from classic cocktails to creative signature blends.$txt34$, array['#ProfessionalBartending', '#WallOfSpirits', '#CreativeCocktails', '#BartendingLivestream', '#CocktailTutorials'],
  'live-streams/tutorials/1/cover.jpg', 'live-streams/tutorials/1/video.mp4',
  35, true, 1
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'tutorials', 'Tutorials', 1, true,
  (select id from _user_rn where rn = 5),
  2, $txt35$Make it right in your kitchen! A beginner-friendly, zero-barrier home bartending mini-class—even total novices can easily whip up delicious signature drinks.$txt35$, array['#HomeBartending', '#BeginnerFriendly', '#HomeCocktails', '#BartendingTutorials', '#EasyBartending'],
  'live-streams/tutorials/2/cover.jpg', 'live-streams/tutorials/2/video.mp4',
  8, true, 2
);

insert into public."Live" (
  category_slug, category_name, category_sort_order, show_on_home,
  streamer_id, room_index, description, tags,
  cover_path, video_path, viewer_count, is_live, sort_order
) values (
  'tutorials', 'Tutorials', 1, true,
  (select id from _user_rn where rn = 6),
  3, $txt36$Live from a real bar counter! Veteran bartenders break down classic cocktail recipes, inviting you to experience the true allure of professional mixology.$txt36$, array['#BarBartending', '#ClassicCocktails', '#ProfessionalTechniques', '#BartenderLife', '#LiveAtTheBar'],
  'live-streams/tutorials/3/cover.jpg', 'live-streams/tutorials/3/video.mp4',
  42, true, 3
);


-- Post
insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 1),
  1, $txt37$A classic in hand, a gentle buzz—drinking in the rituals that enrich everyday life.$txt37$, '[{"type": "video", "storage_path": "moments/1.mp4", "sort_order": 0, "poster_path": "moments/1/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 2),
  2, $txt38$Joy without the alcohol: a collision of coffee and absinthe—keeping you lucid yet delightfully tipsy.$txt38$, '[{"type": "video", "storage_path": "moments/2.mp4", "sort_order": 0, "poster_path": "moments/2/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 3),
  3, $txt39$A creative signature blend that excels in both aesthetics and flavor; every sip is the pure sweetness of fresh fruit.$txt39$, '[{"type": "video", "storage_path": "moments/3.mp4", "sort_order": 0, "poster_path": "moments/3/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 4),
  4, $txt40$The bar counter is a stage, and every bottle toss is a dazzling display of passion and professionalism.$txt40$, '[{"type": "video", "storage_path": "moments/4.mp4", "sort_order": 0, "poster_path": "moments/4/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 5),
  5, $txt41$Shaking a cocktail isn't just about the drink; it’s about the ritual of living. One good drink is enough to soothe away all your weariness.$txt41$, '[{"type": "video", "storage_path": "moments/5.mp4", "sort_order": 0, "poster_path": "moments/5/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 6),
  6, $txt42$Gentle moments at a vintage bar: a glass of freshly mixed magic, raised in a toast to everyone who lives life with earnest dedication.$txt42$, '[{"type": "video", "storage_path": "moments/6.mp4", "sort_order": 0, "poster_path": "moments/6/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 7),
  7, $txt43$The sweet-and-sour tang of passion fruit blossoms within the glass—who else understands the sheer joy of falling in love with a drink at first sip?$txt43$, '[{"type": "video", "storage_path": "moments/7.mp4", "sort_order": 0, "poster_path": "moments/7/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 8),
  8, $txt44$Cocktails & Dreams: at this neon-lit bar, unlock a glass of romance that belongs exclusively to the night.$txt44$, '[{"type": "video", "storage_path": "moments/8.mp4", "sort_order": 0, "poster_path": "moments/8/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 9),
  9, $txt45$The bar is set, the drinks are ready—tonight, your happiness is entirely in the hands of the bartender.$txt45$, '[{"type": "video", "storage_path": "moments/9.mp4", "sort_order": 0, "poster_path": "moments/9/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 10),
  10, $txt46$A drink crafted with meticulous attention to detail; from the shaking to the garnish, every step is a testament to a deep love for the craft.$txt46$, '[{"type": "video", "storage_path": "moments/10.mp4", "sort_order": 0, "poster_path": "moments/10/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 11),
  11, $txt47$Served with precision, locking the full flavor into every single drop—bartending is the romance found in the details.$txt47$, '[{"type": "video", "storage_path": "moments/11.mp4", "sort_order": 0, "poster_path": "moments/11/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 12),
  12, $txt48$The gentle warmth of the wooden bar, the crisp clinking of ice—this chilled drink holds the refreshing coolness of summer within.$txt48$, '[{"type": "video", "storage_path": "moments/12.mp4", "sort_order": 0, "poster_path": "moments/12/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 13),
  13, $txt49$The aromatic zest of orange peel, enveloping the rich body of the spirit—a classic Martini, served with a full sense of ritual.$txt49$, '[{"type": "video", "storage_path": "moments/13.mp4", "sort_order": 0, "poster_path": "moments/13/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 14),
  14, $txt50$Passion is the antidote to the passage of time; shake up a cocktail and smile as you face the little trivialities of daily life.$txt50$, '[{"type": "video", "storage_path": "moments/14.mp4", "sort_order": 0, "poster_path": "moments/14/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 15),
  15, $txt51$Bathed in shifting red and blue light, this signature cocktail is utterly intoxicating—both in its stunning looks and its exquisite flavor.$txt51$, '[{"type": "video", "storage_path": "moments/15.mp4", "sort_order": 0, "poster_path": "moments/15/poster.jpg"}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 16),
  16, $txt52$The pure joy of an Aperol Spritz: a summer romance born from the dance between oranges and sparkling water. If you’ve tasted it, you understand.$txt52$, '[{"type": "image", "storage_path": "moments/16/13d988e9a47e9c0cc686b3a909376bad.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/16/6bd79b5583e9ae03b0308194766b81c6.jpg", "sort_order": 1}, {"type": "image", "storage_path": "moments/16/ab9ec23f687d23b550e32729348355f0.jpg", "sort_order": 2}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 17),
  17, $txt53$The tartness of fresh lime provides the perfect, soothing foundation for a homemade cocktail—sharing a gentle buzz with friends is pure bliss.$txt53$, '[{"type": "image", "storage_path": "moments/17/045fbf1e0738343f7ad7d1ee35c50033.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/17/41ce1d502eee121398b4df0dbe95e885.jpg", "sort_order": 1}, {"type": "image", "storage_path": "moments/17/6d978919ac202732717306a8f1069c03.jpg", "sort_order": 2}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 18),
  18, $txt54$It’s not just the drink that’s pink—it’s the relaxed, carefree mood of the weekend. Shake up a glass and craft a moment of gentle serenity, just for yourself.$txt54$, '[{"type": "image", "storage_path": "moments/18/acd5afb7d087962e920ebb26bb9390b4.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/18/fc9a510bc4ec6260261a807ac92434d8.jpg", "sort_order": 1}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 19),
  19, $txt55$The silky liquid flows through the filter; the aroma of coffee, entwined with the scent of spirits, makes this cup a gentle antidote for the late-night hours.$txt55$, '[{"type": "image", "storage_path": "moments/19/b5c63ea80d9d2867daa46ad4eef5d558.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/19/b605f58807bfa65dc732cfeaabab3198.jpg", "sort_order": 1}]'::jsonb
);

insert into public."Post" (author_id, post_index, content, media) values (
  (select id from _user_rn where rn = 20),
  20, $txt56$With its dense, creamy foam and exquisite garnishes, every cup of coffee liqueur serves as a testament to a sincere dedication—and a deep love—for life.$txt56$, '[{"type": "image", "storage_path": "moments/20/d7ff5ac78a7f50ecf77e5b7eec230e8f.jpg", "sort_order": 0}, {"type": "image", "storage_path": "moments/20/fe3f3d325347e09e9f0bbe11c456fe7f.jpg", "sort_order": 1}]'::jsonb
);


-- Popular Star 展示名
with stars as (
  select id, row_number() over (order by popular_star_sort) as rn from public."User"
  where is_popular_star = true
)
update public."User" u set display_name = v.name
from stars s
join (values
  (1, 'Emerson'), (2, 'Gideon'), (3, 'Casper'), (4, 'Elias'),
  (5, 'Fiona'), (6, 'Hazel'), (7, 'Iris'), (8, 'Juno'), (9, 'Kira'), (10, 'Luna')
) as v(rn, name) on v.rn = s.rn
where u.id = s.id;
