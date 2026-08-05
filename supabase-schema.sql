-- ============================================================
-- 奶龙快跑 🦖 · Supabase 数据库 Schema（最终版）
-- 适用项目：https://stvofpguczogdaxmtqff.supabase.co
-- 维护：cat-bot（绒喵）· 2026-08-05
-- 说明：整段幂等，可重复执行（先 drop 再 create / if not exists）
-- ============================================================

-- ---------- 1. users 表（注册/登录） ----------
create table if not exists users (
  id bigint generated always as identity primary key,
  nickname text not null unique,
  password text not null,          -- 前端 SHA-256 哈希（64 位 hex），非明文
  achievements jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

alter table users enable row level security;

drop policy if exists "insert_user" on users;
drop policy if exists "read_user" on users;
create policy "insert_user" on users for insert
  with check (char_length(nickname) between 1 and 12
              and char_length(password) between 8 and 64);
create policy "read_user" on users for select using (true);

-- ---------- 2. leaderboard 表（极限排行榜） ----------
create table if not exists leaderboard (
  id bigint generated always as identity primary key,
  nickname text not null unique,   -- 一人一条记录
  score int not null,
  equip text,                      -- 佩戴成就 key
  created_at timestamptz default now()
);

alter table leaderboard enable row level security;

drop policy if exists "read_any" on leaderboard;
drop policy if exists "insert_valid" on leaderboard;
create policy "read_any" on leaderboard for select using (true);
create policy "insert_valid" on leaderboard for insert
  with check (score between 0 and 9999 and nickname is not null
              and char_length(nickname) between 1 and 12);

-- ---------- 3. 榜单 RPC：一人一条只留最高分，覆盖时刷新时间戳（同分越早越前） ----------
create or replace function upsert_leaderboard(p_nickname text, p_score int)
returns text as $$
begin
  if p_nickname is null or char_length(p_nickname) < 1 or char_length(p_nickname) > 12 then
    raise exception 'invalid nickname';
  end if;
  if p_score < 0 or p_score > 9999 then
    raise exception 'invalid score';
  end if;
  insert into leaderboard (nickname, score) values (p_nickname, p_score)
  on conflict (nickname) do update set score = excluded.score, created_at = now()
  where leaderboard.score < excluded.score;
  return 'ok';
end $$ language plpgsql security definer;

-- ---------- 4. 佩戴 RPC：白名单校验（8 成就 key） ----------
create or replace function update_equip(p_nickname text, p_equip text)
returns text as $$
begin
  if p_nickname is null or char_length(p_nickname) < 1 or char_length(p_nickname) > 12 then
    raise exception 'invalid nickname';
  end if;
  if p_equip is not null and p_equip not in ('summit','extremeWin','fish6','heliMan','crocHit','snowWalker','thornWalker','unique') then
    raise exception 'invalid equip';
  end if;
  update leaderboard set equip = p_equip where nickname = p_nickname;
  return 'ok';
end $$ language plpgsql security definer;

-- ---------- 5. 成就同步 RPC：白名单校验（8 成就 key，布尔值） ----------
create or replace function sync_achievements(p_nickname text, p_ach jsonb)
returns text as $$
declare
  k text;
begin
  if p_nickname is null or char_length(p_nickname) < 1 or char_length(p_nickname) > 12 then
    raise exception 'invalid nickname';
  end if;
  for k in select jsonb_object_keys(p_ach) loop
    if k not in ('summit','extremeWin','fish6','heliMan','crocHit','snowWalker','thornWalker','unique') then
      raise exception 'invalid achievement key: %', k;
    end if;
    if jsonb_typeof(p_ach -> k) <> 'boolean' then
      raise exception 'invalid achievement value';
    end if;
  end loop;
  update users set achievements = p_ach where nickname = p_nickname;
  return 'ok';
end $$ language plpgsql security definer;

-- ============================================================
-- 成就 key 白名单（8 个，前端 ACHIEVEMENTS 与上述函数必须一致）：
--   summit     🏔️ 抵达雪峰   任意模式到达终点（best≥9999）
--   extremeWin 👑 极限雪峰   极限模式下到达终点
--   fish6      🐟 年年有鱼   终点剩余奶鱼≥6
--   heliMan    🚁 Man！      一局护体撞碎 8 架直升机
--   crocHit    🐊 鳄啊~      一局撞击 3 次鳄鱼
--   snowWalker ❄️ 雪地行者   不耗奶鱼在一场雪天中存活
--   thornWalker 🌵 荆棘行者  荆棘缠身连续前进 2500 分
--   unique     💎 举世无双   完成以上所有成就
-- ============================================================
