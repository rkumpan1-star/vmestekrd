-- ==========================================================
-- ВМЕСТЕ, КРАСНОДАР — схема базы данных для реального приложения
-- Выполнить целиком в Supabase → SQL Editor → Run
-- ==========================================================

-- 1. Тарифы
create table vk_plans (
  id serial primary key,
  name text not null,
  price_rub integer not null,
  duration_months integer not null,
  active boolean default true
);

insert into vk_plans (name, price_rub, duration_months) values
  ('1 месяц', 499, 1),
  ('3 месяца', 1290, 3),
  ('12 месяцев', 3480, 12);

-- 2. Партнёры (каталог заведений)
create table vk_partners (
  id serial primary key,
  name text not null,
  category text not null,          -- 'food' | 'beauty' | 'fit' | 'wear'
  icon text,
  color text,
  perk text not null,
  address text,
  hours text,
  active boolean default true,
  created_at timestamptz default now()
);

insert into vk_partners (name, category, icon, color, perk, address, hours) values
  ('Кофейня «Заедем»', 'food', '☕', '#F3E4D0', 'Апгрейд размера бесплатно', 'ул. Красная, 12', 'Пн–Вс, 8:00–20:00'),
  ('Ресторан «Компот»', 'food', '🍽️', '#F0D8D8', 'Скидка 15% на счёт', 'ул. Мира, 45', 'Будни до 18:00'),
  ('Салон «Причёска+»', 'beauty', '💇', '#F0DCE8', 'Скидка 10% на услугу', 'ул. Ставропольская, 88', 'Пн–Сб, 9:00–21:00'),
  ('Фитнес-клуб «Титан»', 'fit', '🏋️', '#D8E8DC', 'Бесплатное разовое посещение', 'ул. Северная, 200', 'Ежедневно, 6:00–23:00'),
  ('Магазин «Юг Стиль»', 'wear', '👕', '#E4E0F0', 'Скидка 10% на покупку', 'ТЦ «Галерея», 2 этаж', 'Ежедневно, 10:00–22:00'),
  ('SPA «Дыхание»', 'beauty', '🧖', '#DCEAE8', 'Скидка 12% на программу', 'ул. Гоголя, 61', 'Пн–Вс, 10:00–22:00');

-- 3. Подписчики
-- ВАЖНО: сейчас идентификация по номеру телефона без SMS-подтверждения —
-- это упрощение для пилота на малой доверенной группе. Перед реальным запуском
-- с оплатой на широкую аудиторию это нужно заменить на настоящий вход через
-- Supabase Auth (Phone OTP) — иначе кто угодно, зная номер телефона другого
-- человека, теоретически сможет запросить его данные через тот же anon-ключ.
create table vk_subscribers (
  id uuid primary key default gen_random_uuid(),
  phone text unique not null,
  name text,
  created_at timestamptz default now()
);

-- 4. Подписки (история, не только текущий статус)
create table vk_subscriptions (
  id uuid primary key default gen_random_uuid(),
  subscriber_id uuid references vk_subscribers(id) not null,
  plan_id integer references vk_plans(id) not null,
  status text not null default 'pending',   -- pending | active | expired | cancelled
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz default now()
);

-- 5. Платежи — готово под интеграцию ЮKassa, пока без активных ключей
create table vk_payments (
  id uuid primary key default gen_random_uuid(),
  subscriber_id uuid references vk_subscribers(id) not null,
  plan_id integer references vk_plans(id) not null,
  amount_rub integer not null,
  status text not null default 'pending',   -- pending | succeeded | failed | refunded
  provider text default 'yookassa',
  provider_payment_id text,
  created_at timestamptz default now(),
  paid_at timestamptz
);

-- 6. Погашения привилегий (для QR-кода на кассе партнёра)
create table vk_redemptions (
  id uuid primary key default gen_random_uuid(),
  subscriber_id uuid references vk_subscribers(id) not null,
  partner_id integer references vk_partners(id) not null,
  token text unique not null,
  redeemed_at timestamptz default now()
);

-- ==========================================================
-- Row Level Security
-- ==========================================================
alter table vk_plans enable row level security;
alter table vk_partners enable row level security;
alter table vk_subscribers enable row level security;
alter table vk_subscriptions enable row level security;
alter table vk_payments enable row level security;
alter table vk_redemptions enable row level security;

-- Каталог (тарифы и партнёры) — публичное чтение, это витрина
create policy "Публичное чтение тарифов" on vk_plans for select using (active = true);
create policy "Публичное чтение партнёров" on vk_partners for select using (active = true);

-- Подписчики — публичная регистрация и чтение (упрощение пилота, см. комментарий выше)
create policy "Публичная регистрация подписчика" on vk_subscribers for insert with check (true);
create policy "Публичное чтение подписчиков" on vk_subscribers for select using (true);

create policy "Публичное создание подписки" on vk_subscriptions for insert with check (true);
create policy "Публичное чтение подписок" on vk_subscriptions for select using (true);

create policy "Публичное создание платежа" on vk_payments for insert with check (true);
create policy "Публичное чтение платежей" on vk_payments for select using (true);

create policy "Публичное создание погашения" on vk_redemptions for insert with check (true);
create policy "Публичное чтение погашений" on vk_redemptions for select using (true);
