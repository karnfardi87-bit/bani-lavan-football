-- جداول مستقل برای سایت بانی لوان؛ جداول قبلی حذف نمی‌شوند.
create extension if not exists pgcrypto;
create table if not exists public.pitch_bookings(id uuid primary key default gen_random_uuid(),booking_date date not null,slot_key text not null,captain_name text not null,phone text not null,player_count int not null check(player_count between 12 and 16),created_at timestamptz default now(),cancelled_at timestamptz,unique(booking_date,slot_key));
create table if not exists public.pitch_blocked_slots(booking_date date not null,slot_key text not null,primary key(booking_date,slot_key));
create or replace function public.pitch_get_slot_status(p_date date) returns table(slot_key text,status text) language sql security definer set search_path=public as $$
with s(slot_key) as(values('14:00-15:30'),('15:30-17:00'),('17:30-19:00'),('20:00-21:30'),('21:30-23:00'),('23:00-00:30'),('00:30-02:00'))
select s.slot_key,case when exists(select 1 from pitch_blocked_slots b where b.booking_date=p_date and b.slot_key=s.slot_key) then 'blocked' when exists(select 1 from pitch_bookings b where b.booking_date=p_date and b.slot_key=s.slot_key and b.cancelled_at is null) then 'booked' else 'available' end from s;$$;
create or replace function public.pitch_create_booking(p_booking_date date,p_slot_key text,p_captain_name text,p_phone text,p_player_count int) returns uuid language plpgsql security definer set search_path=public as $$
declare new_id uuid;
begin
if p_booking_date<current_date then raise exception 'تاریخ گذشته قابل رزرو نیست';end if;
if p_player_count not between 12 and 16 then raise exception 'تعداد بازیکنان باید ۱۲ تا ۱۶ نفر باشد';end if;
if p_slot_key not in('14:00-15:30','15:30-17:00','17:30-19:00','20:00-21:30','21:30-23:00','23:00-00:30','00:30-02:00') then raise exception 'سانس نامعتبر است';end if;
if exists(select 1 from pitch_blocked_slots where booking_date=p_booking_date and slot_key=p_slot_key) then raise exception 'سانس مسدود است';end if;
insert into pitch_bookings(booking_date,slot_key,captain_name,phone,player_count) values(p_booking_date,p_slot_key,trim(p_captain_name),trim(p_phone),p_player_count) returning id into new_id;return new_id;
exception when unique_violation then raise exception 'این سانس قبلاً رزرو شده است';end;$$;
revoke all on public.pitch_bookings,public.pitch_blocked_slots from anon,authenticated;
grant execute on function public.pitch_get_slot_status(date) to anon,authenticated;
grant execute on function public.pitch_create_booking(date,text,text,text,integer) to anon,authenticated;
