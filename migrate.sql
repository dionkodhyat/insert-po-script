--
-- PostgreSQL database dump
--

-- Dumped from database version 13.3
-- Dumped by pg_dump version 13.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: access_token_platform; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.access_token_platform AS ENUM (
    'Twitch',
    'YouTube',
    'Reddit',
    'Discord',
    'Facebook',
    'Google'
);


--
-- Name: article_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.article_type AS ENUM (
    'HTML',
    'Redirect',
    'File'
);


--
-- Name: career_link_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.career_link_type AS ENUM (
    'Full-Time',
    'Internship',
    'Part-Time'
);


--
-- Name: email_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.email_status AS ENUM (
    'verified',
    'unverified',
    'pending'
);


--
-- Name: homepage_slider_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.homepage_slider_type AS ENUM (
    'Latest Release',
    'Article',
    'Shop',
    'Custom',
    'Gold Early Access',
    'Group'
);


--
-- Name: license_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.license_state AS ENUM (
    'Auto',
    'Enforced',
    'Banned'
);


--
-- Name: TYPE license_state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TYPE public.license_state IS '
    Auto = license is a "regular" license and will be checked.
    Enforced = license is a comped license that wont be checked.
    Banned = license is banned and will never be whitelisted.
';


--
-- Name: license_sync_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.license_sync_state AS ENUM (
    'Success',
    'Failed',
    'Queued'
);


--
-- Name: license_vendor; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.license_vendor AS ENUM (
    'Beam',
    'Twitch',
    'YouTube'
);


--
-- Name: platforms; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.platforms AS ENUM (
    'unknown',
    'website',
    'player-web',
    'player-slobs',
    'player-desktop',
    'connect-ui',
    'connect-api'
);


--
-- Name: shop_code_value_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.shop_code_value_type AS ENUM (
    'Amount',
    'Percentage'
);


--
-- Name: rollup_user_stats(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rollup_user_stats() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO user_stats (user_id, platform_api, platform_slobs, platform_web, platform_website, platform_unknown, last_sync)
    SELECT
      user_id,
      COUNT(*) FILTER (WHERE platform='connect-api'),
      COUNT(*) FILTER (WHERE platform='player-slobs'),
      COUNT(*) FILTER (WHERE platform='player-web'),
      COUNT(*) FILTER (WHERE platform='website'),
      COUNT(*) FILTER (WHERE platform NOT IN ('connect-api', 'player-slobs', 'player-web', 'website')),
      NOW()
    FROM analytic_events
    WHERE created_at > COALESCE((SELECT MAX(last_sync) FROM user_stats), '2000-01-01')
    GROUP BY user_id
    ON CONFLICT (user_id) DO UPDATE SET
        platform_api = user_stats.platform_api + EXCLUDED.platform_api,
        platform_slobs = user_stats.platform_slobs + EXCLUDED.platform_slobs,
        platform_web = user_stats.platform_web + EXCLUDED.platform_web,
        platform_website = user_stats.platform_website + EXCLUDED.platform_website,
        platform_unknown = user_stats.platform_unknown + EXCLUDED.platform_unknown,
        last_sync = EXCLUDED.last_sync;
END
$$;


--
-- Name: FUNCTION rollup_user_stats(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.rollup_user_stats() IS 'Function that incrementally adds any new counts to user_stats instead of scanning entire table';


--
-- Name: trigger_set_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trigger_set_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: analytic_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytic_events (
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    properties jsonb,
    user_id uuid,
    has_gold boolean,
    platform public.platforms DEFAULT 'unknown'::public.platforms
);


--
-- Name: COLUMN analytic_events.has_gold; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.analytic_events.has_gold IS '
  Did the user have gold at time of the event?
  This is nullable because old events did not have this field.
';


--
-- Name: article_artists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_artists (
    article_id uuid NOT NULL,
    artist_id uuid NOT NULL
);


--
-- Name: article_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_categories (
    article_id uuid NOT NULL,
    category_id uuid NOT NULL
);


--
-- Name: article_releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_releases (
    article_id uuid NOT NULL,
    release_id uuid NOT NULL
);


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articles (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    updated timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    vanity_uri text NOT NULL,
    type public.article_type DEFAULT 'HTML'::public.article_type NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    content_raw text DEFAULT ''::text NOT NULL,
    redirect_uri text DEFAULT ''::text NOT NULL,
    file_id uuid,
    cover_file_id uuid,
    summary text DEFAULT ''::text NOT NULL,
    meta_description text DEFAULT ''::text NOT NULL,
    is_published boolean DEFAULT false NOT NULL,
    scheduled_date timestamp with time zone,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    primary_keyword text DEFAULT ''::text NOT NULL,
    secondary_keywords text[],
    tags text[]
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text DEFAULT ''::text NOT NULL
);


--
-- Name: TABLE categories; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.categories IS 'Reason for a table is to be able to add other attributes to categories in the future such as color';


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    birthday date,
    city text DEFAULT ''::text NOT NULL,
    continent text DEFAULT ''::text NOT NULL,
    country text DEFAULT ''::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    email public.citext,
    email_verification_code text DEFAULT ''::text NOT NULL,
    email_verification_status public.email_status,
    first_name text DEFAULT ''::text NOT NULL,
    given_download_access boolean DEFAULT false,
    google_maps_place_id text DEFAULT ''::text NOT NULL,
    klaviyo_id text DEFAULT ''::text NOT NULL,
    last_benefits_update_gold boolean DEFAULT false NOT NULL,
    last_name text DEFAULT ''::text NOT NULL,
    last_seen timestamp with time zone,
    location_lat double precision,
    location_lng double precision,
    max_licenses integer DEFAULT 0 NOT NULL,
    old_email text,
    password text DEFAULT ''::text NOT NULL,
    password_verification_code text DEFAULT ''::text NOT NULL,
    place_name text DEFAULT ''::text NOT NULL,
    place_name_full text DEFAULT ''::text NOT NULL,
    pronouns text DEFAULT ''::text NOT NULL,
    prov_st text DEFAULT ''::text NOT NULL,
    province_state text DEFAULT ''::text NOT NULL,
    real_name text DEFAULT ''::text NOT NULL,
    saysong_twitch_name text,
    two_factor_id text DEFAULT ''::text NOT NULL,
    two_factor_pending_id text DEFAULT ''::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    username text DEFAULT ''::text NOT NULL,
    xsolla_uid text DEFAULT ''::text NOT NULL,
    free_gold boolean DEFAULT false,
    free_gold_reason text DEFAULT ''::text,
    free_gold_at timestamp with time zone,
    my_library uuid
)
WITH (fillfactor='70');


--
-- Name: COLUMN users.given_download_access; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.given_download_access IS '
  This means user was given download access without gold, for example,
  when given to special artists.
';


--
-- Name: articles_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.articles_view AS
 WITH cats AS (
         SELECT array_agg(categories.name) AS names,
            article_categories.article_id
           FROM (public.article_categories
             JOIN public.categories ON ((categories.id = article_categories.category_id)))
          GROUP BY article_categories.article_id
        )
 SELECT articles.id,
    articles.created,
    articles.updated,
    articles.created_by,
    articles.title,
    articles.vanity_uri,
    articles.type,
    articles.content,
    articles.content_raw,
    articles.redirect_uri,
    articles.file_id,
    articles.cover_file_id,
    articles.summary,
    articles.meta_description,
    articles.is_published,
    articles.scheduled_date,
    articles.timezone,
    articles.primary_keyword,
    articles.secondary_keywords,
    articles.tags,
    cats.names AS category_names,
    COALESCE(users.email, ''::public.citext) AS created_by_email,
    COALESCE(users.first_name, ''::text) AS created_by_first_name,
    COALESCE(users.last_name, ''::text) AS created_by_last_name
   FROM ((public.articles
     LEFT JOIN public.users ON ((articles.created_by = users.id)))
     LEFT JOIN cats ON ((cats.article_id = articles.id)));


--
-- Name: careers_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.careers_links (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    publish_date timestamp with time zone DEFAULT now() NOT NULL,
    draft boolean DEFAULT true NOT NULL,
    filled boolean DEFAULT false NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    department text DEFAULT ''::text NOT NULL,
    location text DEFAULT ''::text NOT NULL,
    type public.career_link_type DEFAULT 'Full-Time'::public.career_link_type NOT NULL,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    link text DEFAULT ''::text NOT NULL
);


--
-- Name: categories_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.categories_view AS
 SELECT categories.id,
    categories.name,
    COALESCE(( SELECT count(*) AS count
           FROM public.article_categories
          WHERE (article_categories.category_id = categories.id)), (0)::bigint) AS article_count
   FROM public.categories;


--
-- Name: featured_artists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.featured_artists (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    artist_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: featured_digital_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.featured_digital_events (
    event_id uuid NOT NULL,
    sort integer DEFAULT 0 NOT NULL
);


--
-- Name: TABLE featured_digital_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.featured_digital_events IS 'This table records a list of MCTV events';


--
-- Name: featured_live_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.featured_live_events (
    event_id uuid NOT NULL,
    sort integer DEFAULT 0 NOT NULL
);


--
-- Name: featured_releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.featured_releases (
    release_id uuid NOT NULL,
    sort integer DEFAULT 0 NOT NULL
);


--
-- Name: file_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.file_status (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    file_id uuid,
    user_id uuid,
    action text DEFAULT ''::text NOT NULL,
    status text DEFAULT ''::text NOT NULL,
    message text DEFAULT ''::text NOT NULL
);


--
-- Name: files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.files (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    filepath text DEFAULT ''::text NOT NULL,
    filename text DEFAULT ''::text NOT NULL,
    mime_type text DEFAULT ''::text NOT NULL
);


--
-- Name: files_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.files_view AS
 WITH last_message AS (
         SELECT DISTINCT ON (file_status.file_id) file_status.id,
            file_status.created_at,
            file_status.file_id,
            file_status.user_id,
            file_status.action,
            file_status.status,
            file_status.message
           FROM public.file_status
          ORDER BY file_status.file_id, file_status.created_at DESC
        )
 SELECT files.id,
    files.created_at,
    files.filepath,
    files.filename,
    files.mime_type,
    lm.user_id AS last_user,
    COALESCE(lm.action, ''::text) AS last_action,
    COALESCE(lm.status, ''::text) AS last_status,
    COALESCE(lm.message, ''::text) AS last_message,
    COALESCE(((lm.action = 'delete'::text) AND (lm.status = 'Success'::text)), false) AS deleted
   FROM (public.files
     LEFT JOIN last_message lm ON ((lm.file_id = files.id)));


--
-- Name: gold_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gold_stats (
    id integer NOT NULL,
    auto_gold_users integer,
    auto_gold_users_seen_30 integer,
    auto_gold_users_seen_07 integer,
    free_gold_users integer,
    free_gold_users_seen_30 integer,
    free_gold_users_seen_07 integer,
    gold_users integer,
    gold_users_seen_30 integer,
    gold_users_seen_07 integer,
    paying_subs integer,
    paying_subs_direct integer,
    paying_subs_indirect integer,
    paypal_subs integer,
    paypal_subs_active integer,
    paypal_subs_inactive integer,
    streamlabs_subs integer,
    streamlabs_subs_active integer,
    streamlabs_subs_inactive integer,
    users integer,
    whitelists integer,
    whitelists_active integer,
    whitelists_expired integer,
    xsolla_subs integer,
    xsolla_subs_active integer,
    xsolla_subs_inactive integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: gold_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gold_stats_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gold_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gold_stats_id_seq OWNED BY public.gold_stats.id;


--
-- Name: gold_time_ranges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gold_time_ranges (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid NOT NULL,
    meta jsonb,
    reason text DEFAULT ''::text NOT NULL,
    start timestamp with time zone NOT NULL,
    finish timestamp with time zone NOT NULL,
    CONSTRAINT gold_time_ranges_check CHECK ((start <= finish))
);


--
-- Name: TABLE gold_time_ranges; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.gold_time_ranges IS '
  History of gold. Latest start is latest gold time range.
';


--
-- Name: gold_unsub_survey_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gold_unsub_survey_results (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    sub_id uuid,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    reasons text[] DEFAULT '{}'::text[] NOT NULL,
    comments text DEFAULT ''::text NOT NULL
);


--
-- Name: xsolla_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.xsolla_subscriptions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    archived boolean DEFAULT false,
    date_next_charge timestamp with time zone NOT NULL,
    available_until timestamp with time zone NOT NULL,
    plan_id text NOT NULL,
    subscription_id text NOT NULL,
    status text DEFAULT 'Active'::text,
    user_id uuid NOT NULL
);


--
-- Name: COLUMN xsolla_subscriptions.subscription_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.xsolla_subscriptions.subscription_id IS '
This is the id of the subscription from xsolla itself. This is not the
"table" id column, which is "id".
';


--
-- Name: gold_unsub_survey_results_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.gold_unsub_survey_results_view AS
 SELECT gold_unsub_survey_results.id,
    gold_unsub_survey_results.sub_id,
    gold_unsub_survey_results.completed_at,
    gold_unsub_survey_results.reasons,
    gold_unsub_survey_results.comments,
    xsolla_subscriptions.user_id,
    xsolla_subscriptions.subscription_id AS xsolla_subscription_id,
    xsolla_subscriptions.plan_id AS xsolla_plan_id,
    COALESCE((u.email)::text, u.old_email, ''::text) AS email,
    u.first_name,
    u.last_name,
    u.archived AS user_archived
   FROM ((public.gold_unsub_survey_results
     JOIN public.xsolla_subscriptions ON ((gold_unsub_survey_results.sub_id = xsolla_subscriptions.id)))
     JOIN public.users u ON ((xsolla_subscriptions.user_id = u.id)));


--
-- Name: homepage_slider; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.homepage_slider (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    active boolean DEFAULT false NOT NULL
);


--
-- Name: homepage_slider_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.homepage_slider_item (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    slider_id uuid,
    group_id uuid,
    group_type public.homepage_slider_type,
    sort integer DEFAULT 0 NOT NULL,
    slider_type public.homepage_slider_type NOT NULL,
    category text DEFAULT ''::text NOT NULL,
    brand_id integer,
    article_id uuid,
    link text DEFAULT ''::text NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    subtitle text DEFAULT ''::text NOT NULL,
    background_file_id uuid,
    video_file_id uuid,
    publish_date timestamp with time zone,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    CONSTRAINT homepage_slider_article_check CHECK (((slider_type <> 'Article'::public.homepage_slider_type) OR (article_id IS NOT NULL))),
    CONSTRAINT homepage_slider_custom_check CHECK (((slider_type <> 'Custom'::public.homepage_slider_type) OR ((link <> ''::text) AND (title <> ''::text) AND (subtitle <> ''::text) AND (category <> ''::text) AND (publish_date IS NOT NULL)))),
    CONSTRAINT homepage_slider_group_check CHECK (((group_id IS NULL) OR ((group_type = 'Group'::public.homepage_slider_type) AND (id <> group_id) AND (slider_type <> 'Group'::public.homepage_slider_type)))),
    CONSTRAINT homepage_slider_latest_release_check CHECK (((slider_type <> 'Latest Release'::public.homepage_slider_type) OR (brand_id IS NOT NULL))),
    CONSTRAINT homepage_slider_shop_check CHECK (((slider_type <> 'Shop'::public.homepage_slider_type) OR ((link <> ''::text) AND (title <> ''::text) AND (subtitle <> ''::text) AND (publish_date IS NOT NULL)))),
    CONSTRAINT homepage_slider_xor CHECK ((((group_id IS NULL) AND (slider_id IS NOT NULL)) OR ((group_id IS NOT NULL) AND (slider_id IS NULL))))
);


--
-- Name: homepage_slider_item_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.homepage_slider_item_view AS
 WITH max_sort AS (
         SELECT homepage_slider_item_1.slider_id,
            max(homepage_slider_item_1.sort) AS max_sort
           FROM public.homepage_slider_item homepage_slider_item_1
          GROUP BY homepage_slider_item_1.slider_id
        )
 SELECT homepage_slider_item.id,
    homepage_slider_item.slider_id,
    homepage_slider_item.group_id,
    homepage_slider_item.group_type,
    homepage_slider_item.sort,
    homepage_slider_item.slider_type,
    homepage_slider_item.category,
    homepage_slider_item.brand_id,
    homepage_slider_item.article_id,
    homepage_slider_item.link,
    homepage_slider_item.title,
    homepage_slider_item.subtitle,
    homepage_slider_item.background_file_id,
    homepage_slider_item.video_file_id,
    homepage_slider_item.publish_date,
    homepage_slider_item.timezone,
    COALESCE(hs.name, ''::text) AS slider_name,
    COALESCE(articles.title, ''::text) AS article_title,
    COALESCE(articles.is_published, false) AS article_published,
    COALESCE(articles.scheduled_date, now()) AS article_publish_date,
    COALESCE(articles.vanity_uri, ''::text) AS article_slug,
    COALESCE(max_sort.max_sort, 0) AS max_sort
   FROM (((public.homepage_slider_item
     LEFT JOIN public.articles ON ((homepage_slider_item.article_id = articles.id)))
     LEFT JOIN max_sort ON ((homepage_slider_item.slider_id = max_sort.slider_id)))
     LEFT JOIN public.homepage_slider hs ON ((homepage_slider_item.slider_id = hs.id)));


--
-- Name: http_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.http_sessions (
    id bigint NOT NULL,
    key bytea,
    data bytea,
    created_on timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    modified_on timestamp with time zone,
    expires_on timestamp with time zone
);


--
-- Name: http_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.http_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: http_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.http_sessions_id_seq OWNED BY public.http_sessions.id;


--
-- Name: license_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.license_access_tokens (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    access_token text DEFAULT ''::text NOT NULL,
    refresh_token text DEFAULT ''::text NOT NULL,
    expiry timestamp with time zone DEFAULT now() NOT NULL,
    platform public.access_token_platform NOT NULL,
    channel_id text DEFAULT ''::text NOT NULL
);


--
-- Name: license_time_ranges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.license_time_ranges (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    license_id uuid NOT NULL,
    start timestamp with time zone NOT NULL,
    finish timestamp with time zone NOT NULL,
    source text DEFAULT ''::text NOT NULL,
    gold_time_range_id uuid,
    CONSTRAINT license_time_ranges_check CHECK ((finish >= start))
);


--
-- Name: licenses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.licenses (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    identity text NOT NULL,
    last_sync timestamp with time zone,
    notes text DEFAULT ''::text NOT NULL,
    scheduled_sync timestamp with time zone,
    state public.license_state DEFAULT 'Auto'::public.license_state NOT NULL,
    updated_at timestamp with time zone,
    vendor public.license_vendor NOT NULL,
    user_id uuid,
    archived boolean DEFAULT false NOT NULL,
    sync_state public.license_sync_state DEFAULT 'Queued'::public.license_sync_state NOT NULL,
    sanitized boolean DEFAULT true NOT NULL,
    whitelisted boolean,
    sync_failures integer DEFAULT 0 NOT NULL,
    free boolean DEFAULT false,
    free_reason text DEFAULT ''::text,
    free_at timestamp with time zone,
    invalid boolean DEFAULT false NOT NULL,
    oauth_id uuid
);


--
-- Name: COLUMN licenses.identity; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.licenses.identity IS ' Not unique due to some streamlabs auto adding licenses in the past. ';


--
-- Name: COLUMN licenses.scheduled_sync; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.licenses.scheduled_sync IS ' If today is on or after this date, the license should be resynced (added / removed from YouTube whitelist) if its a YouTube license. This will be nulled out afterwards unless another sync is due. ';


--
-- Name: COLUMN licenses.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.licenses.user_id IS 'If null there is no user attached to this license so that indicates this is a "given" license to someone outside the system.';


--
-- Name: COLUMN licenses.whitelisted; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.licenses.whitelisted IS ' Refers to whether theyre on YouTube Whitelist or not ';


--
-- Name: youtube_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.youtube_stats (
    channel_id text NOT NULL,
    date timestamp with time zone,
    subscribers bigint,
    views bigint,
    title text,
    url text
);


--
-- Name: licenses_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.licenses_view AS
 SELECT licenses.id,
    licenses.created_at,
    licenses.identity,
    licenses.last_sync,
    licenses.notes,
    licenses.scheduled_sync,
    licenses.state,
    licenses.updated_at,
    licenses.vendor,
    licenses.user_id,
    licenses.archived,
    licenses.sync_state,
    licenses.sanitized,
    licenses.whitelisted,
    licenses.sync_failures,
    licenses.free,
    licenses.free_reason,
    licenses.free_at,
    licenses.invalid,
    licenses.oauth_id,
    COALESCE(users.email, ''::public.citext) AS user_email,
    COALESCE(users.archived, false) AS user_archived,
    (licenses.free OR (licenses.state = 'Enforced'::public.license_state) OR (EXISTS ( SELECT license_time_ranges.id,
            license_time_ranges.created_at,
            license_time_ranges.license_id,
            license_time_ranges.start,
            license_time_ranges.finish,
            license_time_ranges.source,
            license_time_ranges.gold_time_range_id
           FROM public.license_time_ranges
          WHERE ((license_time_ranges.license_id = licenses.id) AND ((now() >= (license_time_ranges.start - '12:00:00'::interval)) AND (now() <= (license_time_ranges.finish + '12:00:00'::interval))))))) AS has_active_period,
    youtube_stats.date AS youtube_stats_date,
    COALESCE(youtube_stats.subscribers, (0)::bigint) AS youtube_subscribers,
    COALESCE(youtube_stats.views, (0)::bigint) AS youtube_views,
    COALESCE(youtube_stats.url, ''::text) AS youtube_url,
    COALESCE(youtube_stats.title, ''::text) AS youtube_title
   FROM ((public.licenses
     LEFT JOIN public.users ON ((users.id = licenses.user_id)))
     LEFT JOIN LATERAL ( SELECT youtube_stats_1.channel_id,
            youtube_stats_1.date,
            youtube_stats_1.subscribers,
            youtube_stats_1.views,
            youtube_stats_1.title,
            youtube_stats_1.url
           FROM public.youtube_stats youtube_stats_1
          WHERE (youtube_stats_1.channel_id = licenses.identity)
          ORDER BY youtube_stats_1.date DESC
         LIMIT 1) youtube_stats ON (true))
  WHERE (licenses.archived = false);


--
-- Name: VIEW licenses_view; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.licenses_view IS 'Has a buffer of 12 hours between start and end dates in case of failed payments or late payments. If they fail a payment within this period, they will be unwhitelisted but this is fine since once the payment goest through they should be rewhitelisted.';


--
-- Name: COLUMN licenses_view.has_active_period; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.licenses_view.has_active_period IS 'Means they have an active subscription at the current moment in time.';


--
-- Name: menu_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_items (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    section_id uuid NOT NULL,
    label text DEFAULT ''::text NOT NULL,
    link text DEFAULT ''::text NOT NULL,
    sort integer DEFAULT 0 NOT NULL
);


--
-- Name: menu_sections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_sections (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    menu_id uuid NOT NULL,
    label text DEFAULT ''::text NOT NULL,
    icon text DEFAULT ''::text NOT NULL,
    sort integer DEFAULT 0 NOT NULL
);


--
-- Name: menus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menus (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    code text
);


--
-- Name: mood_omitted_songs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mood_omitted_songs (
    mood_id uuid NOT NULL,
    track_id uuid NOT NULL,
    release_id uuid NOT NULL
);


--
-- Name: mood_params; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mood_params (
    mood_id uuid NOT NULL,
    param text NOT NULL,
    min double precision,
    max double precision
);


--
-- Name: moods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.moods (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    uri text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    omitted_genres text[],
    start_date timestamp with time zone,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    tile_file_id uuid,
    background_file_id uuid
);


--
-- Name: page_counter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.page_counter (
    page text NOT NULL,
    num integer
);


--
-- Name: TABLE page_counter; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.page_counter IS 'A simple table to count pages visited. You can delete this after 9 year is done or continue to use it.';


--
-- Name: paypal_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paypal_payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    fees text,
    gross text,
    payment_id text,
    paypal_subscription_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    details jsonb,
    notes text DEFAULT ''::text,
    gold_time_range_id uuid NOT NULL
);


--
-- Name: paypal_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paypal_subscriptions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    pp_subscription_id text,
    pp_customer_id text,
    status text DEFAULT 'Active'::text,
    user_id uuid NOT NULL
);


--
-- Name: COLUMN paypal_subscriptions.pp_subscription_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paypal_subscriptions.pp_subscription_id IS '
  This is the recurring_payment_id in paypal webhook.
';


--
-- Name: COLUMN paypal_subscriptions.pp_customer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.paypal_subscriptions.pp_customer_id IS '
  This is the payer_id in paypal webhook.
';


--
-- Name: playlist_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playlist_items (
    playlist_id uuid NOT NULL,
    track_id uuid,
    release_id uuid,
    sort integer DEFAULT 0 NOT NULL
);


--
-- Name: playlist_items_ordered_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.playlist_items_ordered_view AS
 SELECT playlist_items.playlist_id,
    playlist_items.track_id,
    playlist_items.release_id,
    playlist_items.sort,
    playlist_items.ctid,
    (row_number() OVER (PARTITION BY playlist_items.playlist_id ORDER BY playlist_items.sort) - 1) AS cleaned_sort
   FROM public.playlist_items;


--
-- Name: playlists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playlists (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid,
    description text DEFAULT ''::text NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    public boolean DEFAULT false NOT NULL,
    tile_file_id uuid,
    background_file_id uuid
);


--
-- Name: playlists_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.playlists_view AS
 SELECT playlists.id,
    playlists.created_at,
    playlists.updated_at,
    playlists.user_id,
    playlists.description,
    playlists.archived,
    playlists.name,
    playlists.public,
    playlists.tile_file_id,
    playlists.background_file_id,
    ( SELECT count(*) AS count
           FROM public.playlist_items
          WHERE (playlist_items.playlist_id = playlists.id)) AS num_records,
    (EXISTS ( SELECT users.id,
            users.archived,
            users.attributes,
            users.birthday,
            users.city,
            users.continent,
            users.country,
            users.created_at,
            users.email,
            users.email_verification_code,
            users.email_verification_status,
            users.first_name,
            users.given_download_access,
            users.google_maps_place_id,
            users.klaviyo_id,
            users.last_benefits_update_gold,
            users.last_name,
            users.last_seen,
            users.location_lat,
            users.location_lng,
            users.max_licenses,
            users.old_email,
            users.password,
            users.password_verification_code,
            users.place_name,
            users.place_name_full,
            users.pronouns,
            users.prov_st,
            users.province_state,
            users.real_name,
            users.saysong_twitch_name,
            users.two_factor_id,
            users.two_factor_pending_id,
            users.updated_at,
            users.username,
            users.xsolla_uid,
            users.free_gold,
            users.free_gold_reason,
            users.free_gold_at,
            users.my_library
           FROM public.users
          WHERE (users.my_library = playlists.id))) AS my_library
   FROM public.playlists;


--
-- Name: podcast_stations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.podcast_stations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    podcast_id uuid NOT NULL,
    territory_id uuid NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    local_air_time text DEFAULT ''::text NOT NULL,
    image_url text DEFAULT ''::text NOT NULL,
    website_url text DEFAULT ''::text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


--
-- Name: territories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.territories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text DEFAULT ''::text NOT NULL
);


--
-- Name: podcast_stations_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.podcast_stations_view AS
 SELECT s.id,
    s.podcast_id,
    s.territory_id,
    s.title,
    s.local_air_time,
    s.image_url,
    s.website_url,
    s.sort_order,
    t.name AS territory_name
   FROM (public.podcast_stations s
     JOIN public.territories t ON ((t.id = s.territory_id)));


--
-- Name: podcasts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.podcasts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    links text[] DEFAULT '{}'::text[] NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    brand integer DEFAULT 0 NOT NULL,
    uri text NOT NULL
);


--
-- Name: poll_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_options (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    poll_id uuid,
    sort integer DEFAULT 0 NOT NULL,
    tags text[],
    details jsonb
);


--
-- Name: poll_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_votes (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    option_id uuid,
    ip_address text DEFAULT ''::text NOT NULL,
    user_agent text DEFAULT ''::text NOT NULL,
    vote_time timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN poll_votes.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.poll_votes.user_id IS 'This is the user that did the vote. We need this to contain the information even after the user has been deleted, so we cannot reference user(id)';


--
-- Name: poll_user_num_votes_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.poll_user_num_votes_view AS
 SELECT poll_options.poll_id,
    poll_votes.user_id,
    count(*) AS num_votes
   FROM (public.poll_votes
     JOIN public.poll_options ON ((poll_votes.option_id = poll_options.id)))
  GROUP BY poll_options.poll_id, poll_votes.user_id;


--
-- Name: user_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_stats (
    user_id uuid,
    platform_api bigint DEFAULT 0,
    platform_slobs bigint DEFAULT 0,
    platform_web bigint DEFAULT 0,
    platform_website bigint DEFAULT 0,
    platform_unknown bigint DEFAULT 0,
    last_sync timestamp with time zone
);


--
-- Name: TABLE user_stats; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_stats IS 'Per user stats that are refreshed nightly.';


--
-- Name: COLUMN user_stats.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_stats.user_id IS 'This is unique because it can also be null in case of anonymous user.';


--
-- Name: users_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.users_view AS
 SELECT users.id,
    users.archived,
    users.attributes,
    users.birthday,
    users.city,
    users.continent,
    users.country,
    users.created_at,
    users.email,
    users.email_verification_code,
    users.email_verification_status,
    users.first_name,
    users.given_download_access,
    users.google_maps_place_id,
    users.klaviyo_id,
    users.last_benefits_update_gold,
    users.last_name,
    users.last_seen,
    users.location_lat,
    users.location_lng,
    users.max_licenses,
    users.old_email,
    users.password,
    users.password_verification_code,
    users.place_name,
    users.place_name_full,
    users.pronouns,
    users.prov_st,
    users.province_state,
    users.real_name,
    users.saysong_twitch_name,
    users.two_factor_id,
    users.two_factor_pending_id,
    users.updated_at,
    users.username,
    users.xsolla_uid,
    users.free_gold,
    users.free_gold_reason,
    users.free_gold_at,
    users.my_library,
    (users.free_gold OR (EXISTS ( SELECT gold_time_ranges.id,
            gold_time_ranges.created_at,
            gold_time_ranges.user_id,
            gold_time_ranges.meta,
            gold_time_ranges.reason,
            gold_time_ranges.start,
            gold_time_ranges.finish
           FROM public.gold_time_ranges
          WHERE ((gold_time_ranges.user_id = users.id) AND ((now() >= gold_time_ranges.start) AND (now() <= gold_time_ranges.finish)))))) AS has_gold,
    (users.given_download_access OR users.free_gold OR (EXISTS ( SELECT gold_time_ranges.id,
            gold_time_ranges.created_at,
            gold_time_ranges.user_id,
            gold_time_ranges.meta,
            gold_time_ranges.reason,
            gold_time_ranges.start,
            gold_time_ranges.finish
           FROM public.gold_time_ranges
          WHERE ((gold_time_ranges.user_id = users.id) AND ((now() >= gold_time_ranges.start) AND (now() <= gold_time_ranges.finish)))))) AS has_download,
    (users.password <> ''::text) AS has_password,
    x.available_until AS subscription_end_date,
    COALESCE(( SELECT date_part('day'::text, sum((LEAST(now(), gold_time_ranges.finish) - gold_time_ranges.start))) AS date_part
           FROM public.gold_time_ranges
          WHERE (gold_time_ranges.user_id = users.id)), (0)::double precision) AS days_subscribed,
    COALESCE(user_stats.platform_api, (0)::bigint) AS platform_api,
    COALESCE(user_stats.platform_slobs, (0)::bigint) AS platform_slobs,
    COALESCE(user_stats.platform_web, (0)::bigint) AS platform_web,
    COALESCE(user_stats.platform_website, (0)::bigint) AS platform_website,
    COALESCE(user_stats.platform_unknown, (0)::bigint) AS platform_unknown,
    COALESCE(x.status, ''::text) AS subscription_status,
    COALESCE(x.plan_id, ''::text) AS subscription_plan_id
   FROM ((public.users
     LEFT JOIN public.xsolla_subscriptions x ON ((x.user_id = users.id)))
     LEFT JOIN public.user_stats ON ((user_stats.user_id = users.id)));


--
-- Name: VIEW users_view; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.users_view IS 'There is a distinction between has_gold and has_download because at some point someone wanted to give people gold without the early access benefits and vice versa.';


--
-- Name: poll_votes_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.poll_votes_view AS
 WITH u AS (
         SELECT u_1.id,
            u_1.email,
            u_1.created_at,
            (u_1.email_verification_status = 'verified'::public.email_status) AS has_verified_email,
            u_1.has_gold,
            (u_1.two_factor_id <> ''::text) AS has_two_factor,
            (u_1.created_at <= (now() - '1 mon'::interval)) AS membership_1_month,
            (u_1.created_at <= (now() - '1 year'::interval)) AS membership_1_year
           FROM public.users_view u_1
        )
 SELECT poll_votes.id,
    poll_votes.user_id,
    poll_votes.option_id,
    poll_votes.ip_address,
    poll_votes.user_agent,
    poll_votes.vote_time,
    po.poll_id,
    po.title,
    po.details,
    po.tags,
    u.email,
    u.has_verified_email,
    u.has_gold,
    u.has_two_factor,
    u.membership_1_month,
    u.membership_1_year,
    u.created_at AS user_created_at,
    (((((u.has_verified_email)::integer + ((u.has_gold)::integer * 3)) + ((u.has_two_factor)::integer * 2)) + (u.membership_1_month)::integer) + (u.membership_1_year)::integer) AS score
   FROM ((public.poll_votes
     JOIN public.poll_options po ON ((poll_votes.option_id = po.id)))
     JOIN u ON ((u.id = poll_votes.user_id)));


--
-- Name: polls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.polls (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    category text NOT NULL,
    title text,
    start_date timestamp with time zone,
    end_date timestamp with time zone,
    timezone text DEFAULT 'America/Vancouver'::text NOT NULL,
    min_choices integer DEFAULT 1 NOT NULL,
    max_choices integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    public_results_limit integer DEFAULT 0 NOT NULL,
    public_vote_count boolean DEFAULT false NOT NULL
);


--
-- Name: polls_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.polls_view AS
 SELECT polls.id,
    polls.archived,
    polls.category,
    polls.title,
    polls.start_date,
    polls.end_date,
    polls.timezone,
    polls.min_choices,
    polls.max_choices,
    polls.created_at,
    polls.updated_at,
    polls.public_results_limit,
    polls.public_vote_count,
    COALESCE(( SELECT count(*) AS count
           FROM public.poll_options
          WHERE (poll_options.poll_id = polls.id)), (0)::bigint) AS num_options
   FROM public.polls;


--
-- Name: streamlabs_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.streamlabs_profiles (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    streamlabs_uid integer DEFAULT 0 NOT NULL,
    streamlabs_name text DEFAULT ''::text NOT NULL,
    streamlabs_prime boolean DEFAULT false NOT NULL,
    twitch_id integer DEFAULT 0 NOT NULL,
    twitch_display_name text DEFAULT ''::text NOT NULL,
    mixer_id integer DEFAULT 0 NOT NULL,
    mixer_display_name text DEFAULT ''::text NOT NULL,
    youtube_id text DEFAULT ''::text NOT NULL,
    youtube_display_name text DEFAULT ''::text NOT NULL
);


--
-- Name: saysong_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.saysong_view AS
 SELECT u.id AS user_id,
    COALESCE(u.saysong_twitch_name, sp.twitch_display_name, ''::text) AS twitch_name
   FROM (public.users u
     LEFT JOIN public.streamlabs_profiles sp ON ((u.id = sp.user_id)));


--
-- Name: shop_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shop_codes (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    description text,
    expires_at timestamp with time zone,
    updated_at timestamp with time zone,
    discount_value text,
    user_id uuid,
    value text DEFAULT ''::text NOT NULL,
    value_type public.shop_code_value_type
);


--
-- Name: social_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_access_tokens (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    access_token text DEFAULT ''::text NOT NULL,
    refresh_token text DEFAULT ''::text NOT NULL,
    expiry timestamp with time zone DEFAULT now() NOT NULL,
    platform public.access_token_platform NOT NULL,
    identity text DEFAULT ''::text NOT NULL,
    legacy boolean DEFAULT false NOT NULL
);


--
-- Name: streamlabs_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.streamlabs_payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    streamlabs_subscription_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    gold_time_range_id uuid NOT NULL
);


--
-- Name: streamlabs_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.streamlabs_subscriptions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    sl_subscription_id integer,
    sl_uid integer,
    status text DEFAULT 'Active'::text,
    user_id uuid NOT NULL
);


--
-- Name: user_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_features (
    user_id uuid NOT NULL,
    feature text NOT NULL
);


--
-- Name: user_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_settings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    hide_unlicensable_tracks boolean DEFAULT false NOT NULL,
    block_unlicensable_tracks boolean DEFAULT false NOT NULL,
    playlist_public_by_default boolean DEFAULT false NOT NULL,
    preferred_download_format text DEFAULT 'mp3_320'::text NOT NULL,
    auto_enable_streamer_mode boolean DEFAULT true NOT NULL,
    user_id uuid
);


--
-- Name: webhook_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_logs (
    id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    data json NOT NULL,
    raw_data text DEFAULT ''::text,
    provider text NOT NULL,
    url text NOT NULL,
    hash text,
    handled boolean DEFAULT false
);


--
-- Name: COLUMN webhook_logs.data; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.webhook_logs.data IS 'Raw data from webhook in json form for querying.';


--
-- Name: COLUMN webhook_logs.raw_data; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.webhook_logs.raw_data IS 'Raw data from webhook body as opposed to data which is the data json serialized for querying purposes.';


--
-- Name: COLUMN webhook_logs.hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.webhook_logs.hash IS 'SHA256 hash of the raw webhook data';


--
-- Name: COLUMN webhook_logs.handled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.webhook_logs.handled IS 'Webhook may be sent twice due to internet flakiness, sender issues or receiver issues. Only unique index when handled true because I want to log ALL webhooks including duplicates but only one webhook should actually be handled.';


--
-- Name: webhook_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.webhook_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: webhook_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.webhook_logs_id_seq OWNED BY public.webhook_logs.id;


--
-- Name: xsolla_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.xsolla_payments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    amount text,
    archived boolean DEFAULT false,
    payment_id text,
    xsolla_subscription_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    details jsonb DEFAULT '{}'::jsonb,
    gold_time_range_id uuid NOT NULL
);


--
-- Name: COLUMN xsolla_payments.details; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.xsolla_payments.details IS '
  All the miscellaneous data included in a webhook.
';


--
-- Name: youtube_latest_stat_scrape; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.youtube_latest_stat_scrape AS
 SELECT licenses.identity,
    '0001-01-01 00:00:00-08:12:28'::timestamp with time zone AS date
   FROM public.licenses
  WHERE ((licenses.vendor = 'YouTube'::public.license_vendor) AND (NOT (licenses.identity IN ( SELECT youtube_stats.channel_id
           FROM public.youtube_stats))) AND (NOT licenses.archived) AND (NOT licenses.invalid))
UNION
 SELECT youtube_stats.channel_id AS identity,
    max(youtube_stats.date) AS date
   FROM (public.youtube_stats
     JOIN public.licenses ON ((licenses.identity = youtube_stats.channel_id)))
  WHERE ((NOT licenses.archived) AND (NOT licenses.invalid))
  GROUP BY youtube_stats.channel_id;


--
-- Name: gold_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gold_stats ALTER COLUMN id SET DEFAULT nextval('public.gold_stats_id_seq'::regclass);


--
-- Name: http_sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.http_sessions ALTER COLUMN id SET DEFAULT nextval('public.http_sessions_id_seq'::regclass);


--
-- Name: webhook_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_logs ALTER COLUMN id SET DEFAULT nextval('public.webhook_logs_id_seq'::regclass);


--
-- Data for Name: analytic_events; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: article_artists; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: article_categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.article_categories VALUES ('f7960b2d-fc18-42c4-b383-f0c4f6495a98', '236506b6-3b4b-4531-b1a6-e23b69c33af7');
INSERT INTO public.article_categories VALUES ('ae527919-7725-4cd8-aa3f-5838fc4b819a', '236506b6-3b4b-4531-b1a6-e23b69c33af7');
INSERT INTO public.article_categories VALUES ('218b10df-2f15-46fe-a814-a205c8979920', '304819e5-bde3-4aaf-b748-0d4a8b52921f');
INSERT INTO public.article_categories VALUES ('bc2b0dab-5436-410e-9cad-37b850da66b3', '304819e5-bde3-4aaf-b748-0d4a8b52921f');
INSERT INTO public.article_categories VALUES ('2c69980d-9b28-4013-a4b6-b820ca30917b', '448a4dc9-dbe2-467b-b1e6-91ccfd8c30ea');
INSERT INTO public.article_categories VALUES ('2b8fc4f3-c71e-4647-86a8-12838dc22a4f', 'd31b0e81-40d4-4fa7-9341-03375630c8a8');
INSERT INTO public.article_categories VALUES ('35244d0e-91d0-4a98-bbb5-460aba674d5c', 'd7b92deb-e2bf-4f66-8508-e9ffedf47c1c');
INSERT INTO public.article_categories VALUES ('9affb872-3b8e-4883-a3b9-ad1a61d8c84a', 'd7b92deb-e2bf-4f66-8508-e9ffedf47c1c');
INSERT INTO public.article_categories VALUES ('242e69ac-036a-4899-a20b-e8e63feaa677', 'd7b92deb-e2bf-4f66-8508-e9ffedf47c1c');
INSERT INTO public.article_categories VALUES ('8d072897-7e29-47b2-97bd-95c5f9db7fdf', 'd7b92deb-e2bf-4f66-8508-e9ffedf47c1c');
INSERT INTO public.article_categories VALUES ('cefe684d-2597-486e-a0ec-848ef677a36b', 'd7b92deb-e2bf-4f66-8508-e9ffedf47c1c');


--
-- Data for Name: article_releases; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: articles; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.articles VALUES ('ae527919-7725-4cd8-aa3f-5838fc4b819a', '2021-05-28 21:39:18.999557-07', '2021-06-25 12:24:11.438282-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'New crypto discovered.', 'new-crypto', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', '', '', NULL, '94ff8d9d-acb6-49be-b212-c8e703b6f8e9', 'Today was the discovery of a brand new crypto.', '', true, '2021-05-28 17:22:09.745651-07', 'UTC', '', NULL, '{article}');
INSERT INTO public.articles VALUES ('2c69980d-9b28-4013-a4b6-b820ca30917b', '2021-05-28 21:39:18.999557-07', '2021-05-28 21:39:18.999557-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Lets plant a tree', 'plant-trees', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', '', '', NULL, '94ff8d9d-acb6-49be-b212-c8e703b6f8e9', 'Today is the best day to plant a tree.', '', true, '2021-03-30 17:22:09.745651-07', 'UTC', '', NULL, '{article}');
INSERT INTO public.articles VALUES ('35244d0e-91d0-4a98-bbb5-460aba674d5c', '2021-05-28 21:39:18.999557-07', '2021-05-28 21:39:18.999557-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Label releases new Vinyl Albums.', 'vinyl-albums', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', '', '', NULL, '94ff8d9d-acb6-49be-b212-c8e703b6f8e9', 'Aiming for a retro feel, label releases new vinyl records.', '', true, '2021-03-22 17:22:09.745651-07', 'UTC', '', NULL, '{article}');
INSERT INTO public.articles VALUES ('218b10df-2f15-46fe-a814-a205c8979920', '2021-05-28 21:39:18.999557-07', '2021-05-28 21:39:18.999557-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Interview with Mozart.', 'mozart', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', '', '', NULL, '94ff8d9d-acb6-49be-b212-c8e703b6f8e9', 'Today we have a special guest interview.', '', true, '2021-05-28 17:22:09.745651-07', 'UTC', '', NULL, '{article}');
INSERT INTO public.articles VALUES ('2b8fc4f3-c71e-4647-86a8-12838dc22a4f', '2021-05-28 21:39:18.999557-07', '2021-05-28 21:39:18.999557-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Label partners with Fortnite.', 'partners-with-fortnite', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', '', '', NULL, '94ff8d9d-acb6-49be-b212-c8e703b6f8e9', 'A deep dive into the partner ship between the label and a video game company', '', true, '2021-04-10 17:22:09.745651-07', 'UTC', '', NULL, NULL);
INSERT INTO public.articles VALUES ('bc2b0dab-5436-410e-9cad-37b850da66b3', '2021-05-28 21:39:18.999557-07', '2021-05-28 21:39:18.999557-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Interview with Bob Ross.', 'bob-ross', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', '', '', NULL, '94ff8d9d-acb6-49be-b212-c8e703b6f8e9', 'Today we have a special guest interview with Bob Ross.', '', true, '2021-06-19 17:22:09.745651-07', 'UTC', '', NULL, '{news}');
INSERT INTO public.articles VALUES ('f7960b2d-fc18-42c4-b383-f0c4f6495a98', '2021-05-28 21:39:18.999557-07', '2021-05-28 21:39:18.999557-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'New planet discovered.', 'new-planet', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', '', '', NULL, '94ff8d9d-acb6-49be-b212-c8e703b6f8e9', 'A new inhabitable planet has been discovered.', '', true, '2021-05-30 17:22:09.745651-07', 'UTC', '', NULL, '{article}');
INSERT INTO public.articles VALUES ('9affb872-3b8e-4883-a3b9-ad1a61d8c84a', '2021-07-09 10:21:54.563106-07', '2021-07-09 10:28:33.915491-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'The "Skin-spiration" behind Smite''s Monstercat Battle Pass', 'mcat-battle-pass', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', 'Todo something something', '', NULL, '54e49391-ac15-494e-9621-c6c894570a40', 'Smite, Paladins, Overwatch.', '', true, '2021-07-09 10:21:54.563106-07', 'UTC', '', '{}', '{}');
INSERT INTO public.articles VALUES ('242e69ac-036a-4899-a20b-e8e63feaa677', '2021-07-09 10:22:36.386691-07', '2021-07-09 10:28:40.692981-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Inside Kaskade’s ‘Visceral’ Fortnite Concert Tonight', 'kaskade-visceral', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', 'Todo something something', '', NULL, '104c2a6b-5912-4c88-9c9b-f77fc604f444', 'Combining live concerts with gaming, join this special concert.', '', true, '2021-07-09 10:22:36.386691-07', 'UTC', '', '{}', '{}');
INSERT INTO public.articles VALUES ('8d072897-7e29-47b2-97bd-95c5f9db7fdf', '2021-07-09 10:22:50.538846-07', '2021-07-09 10:28:40.968249-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Something About Monstercat and Rocket League Here', 'rock-league', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', 'Todo something something', '', NULL, '2b665fa9-cd6b-4f46-a2ff-1c695f0c7a34', 'Unique Gaming and Label collab to be released.', '', true, '2021-07-09 10:22:50.538846-07', 'UTC', '', '{}', '{}');
INSERT INTO public.articles VALUES ('cefe684d-2597-486e-a0ec-848ef677a36b', '2021-07-09 10:23:03.794666-07', '2021-07-09 10:28:41.184416-07', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'Linden Labs''s Sansar Partners With Monstercat to Bring Live Music Into VR', 'linden', 'HTML', '<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p><p>Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo. Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit, sed quia non numquam eius modi tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim ad minima veniam, quis nostrum exercitationem ullam corporis suscipit laboriosam, nisi ut aliquid ex ea commodi consequatur? Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo voluptas nulla pariatur?</p>', 'Todo something something', '', NULL, '0c1a0b44-d1f7-4cb9-aa13-48d726f957e6', 'Music + VR combo for max realism.', '', true, '2021-07-09 10:23:03.794666-07', 'UTC', '', '{}', '{}');


--
-- Data for Name: careers_links; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.careers_links VALUES ('857124a4-1ef0-4b23-9b37-d96dfa1fc195', '2021-11-16 15:29:22.481384-08', false, false, 'Test Position', 'Technology', 'Vancouver, BC', 'Full-Time', 'UTC', 'https://google.com');


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.categories VALUES ('236506b6-3b4b-4531-b1a6-e23b69c33af7', 'Announcements');
INSERT INTO public.categories VALUES ('304819e5-bde3-4aaf-b748-0d4a8b52921f', 'Artist Features');
INSERT INTO public.categories VALUES ('7869f246-1347-4b50-a07d-e6c3e0e1bfce', 'Lost Civ');
INSERT INTO public.categories VALUES ('448a4dc9-dbe2-467b-b1e6-91ccfd8c30ea', 'Headline');
INSERT INTO public.categories VALUES ('d7b92deb-e2bf-4f66-8508-e9ffedf47c1c', 'Press');
INSERT INTO public.categories VALUES ('d31b0e81-40d4-4fa7-9341-03375630c8a8', 'Case Study');


--
-- Data for Name: featured_artists; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: featured_digital_events; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: featured_live_events; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: featured_releases; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.featured_releases VALUES ('5f15ac13-80a0-48a2-b300-9bbe4cfdd34a', 1);
INSERT INTO public.featured_releases VALUES ('d11f7660-8fcb-47a0-b695-a02866ce528e', 2);
INSERT INTO public.featured_releases VALUES ('635bf298-8d4c-4a1f-9c38-d21c59bc0b96', 3);
INSERT INTO public.featured_releases VALUES ('28593acb-1d63-468e-939e-54ed3d1d4323', 4);
INSERT INTO public.featured_releases VALUES ('1efacac1-0262-4aa3-a284-e15100acc504', 5);
INSERT INTO public.featured_releases VALUES ('6d0bab86-d6c8-44e7-bc4c-c3c665cb85fa', 6);


--
-- Data for Name: file_status; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.file_status VALUES ('a1153d61-46c4-49b7-a522-3444c3c709f2', '2021-02-02 04:20:53.447658-08', '2cba5510-86dc-419c-a3ee-43db07e9b2d6', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('5b0e8ee5-007d-41aa-8894-ee6516ae349b', '2021-02-02 04:20:55.447658-08', '2cba5510-86dc-419c-a3ee-43db07e9b2d6', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('7f0e7df6-5262-4c94-8b04-b5beecb9a6cb', '2021-02-02 04:21:41.218109-08', 'ff0c3d02-ba8e-48fc-838b-b40b04f39dbc', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('48a70a68-9236-49d7-ad25-c63d4d5c9426', '2021-02-02 04:21:44.218109-08', 'ff0c3d02-ba8e-48fc-838b-b40b04f39dbc', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('3b45a4e3-1789-4f85-911a-af443934c39d', '2021-02-02 04:21:41.218109-08', 'ff0c3d02-ba8e-48fc-838b-b40b04f39dbc', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'delete', 'Started', '');
INSERT INTO public.file_status VALUES ('5cf45bbf-2cdd-49d8-bd20-9d68b49e2c9f', '2021-02-02 04:21:45.218109-08', 'ff0c3d02-ba8e-48fc-838b-b40b04f39dbc', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'delete', 'Error', 'file not found');
INSERT INTO public.file_status VALUES ('c44d2671-ba31-4cfa-9ac3-3bf086befb01', '2021-02-02 04:22:53.447658-08', '2cba5510-86dc-419c-a3ee-43db07e9b2d6', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'delete', 'Started', '');
INSERT INTO public.file_status VALUES ('81b02df2-4f78-4c7d-b491-f60f68bdefc3', '2021-02-02 04:22:55.447658-08', '2cba5510-86dc-419c-a3ee-43db07e9b2d6', '1df819ef-074c-40b3-99b2-8992e59edd7d', 'delete', 'Success', '');
INSERT INTO public.file_status VALUES ('a08f0e86-2979-40f8-aaf3-6f97d46b0614', '2021-04-21 22:07:00.721443-07', 'c46c960e-803c-4716-8803-d9673404a020', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('81b39de0-7895-4400-92b9-ba64e01d9444', '2021-04-21 22:07:00.912238-07', 'c46c960e-803c-4716-8803-d9673404a020', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('1caede19-9c4b-4b97-a6ab-3a06f60323ab', '2021-04-21 22:07:26.600822-07', '915899f6-c1e8-449e-be12-d98e1c17bb70', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('65fa2531-4143-4657-ab53-a51a11f9b254', '2021-04-21 22:07:26.814167-07', '915899f6-c1e8-449e-be12-d98e1c17bb70', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('d2085d32-5808-4bcf-8655-eec3769bc0da', '2021-04-21 22:07:47.962718-07', 'c4e8ea82-05a0-4015-b0f1-0a8bf4b81b8a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('0d328023-7dbd-4543-8419-dc4121299942', '2021-04-21 22:07:48.195429-07', 'c4e8ea82-05a0-4015-b0f1-0a8bf4b81b8a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('ed083471-2fe0-4086-9183-b7806bc85685', '2021-04-21 22:10:50.323823-07', '00f1b4d5-28db-4c62-852f-dbf20542cc44', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('dcc8c491-1a31-401e-8cec-77d0c1fc70fe', '2021-04-21 22:10:50.519787-07', '00f1b4d5-28db-4c62-852f-dbf20542cc44', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('b4592549-3ed4-4a6a-a0db-2767104d710f', '2021-04-21 22:12:50.125355-07', '71f3e46c-17c4-4253-a218-cbd9ef867961', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('d21c0e61-9c15-4ace-b3a9-c2f3c22a1278', '2021-04-21 22:12:50.271943-07', '71f3e46c-17c4-4253-a218-cbd9ef867961', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('d6a4b5b5-ad1a-4158-a7b6-4ed12827085f', '2021-04-21 22:13:17.787721-07', 'b97b5a5e-e11e-4e1b-9dfe-7ac7e9b739c4', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('6d816c26-88cf-47ed-a727-0c37d0cd7a16', '2021-04-21 22:13:17.951799-07', 'b97b5a5e-e11e-4e1b-9dfe-7ac7e9b739c4', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('3c374e63-d261-46e0-b667-8ef9cbeec6bc', '2021-04-21 22:13:37.028265-07', '4eaf14e6-aa65-4cbf-a827-3c026666b6ac', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('65bb7dc1-230e-4156-ab25-f756da82b143', '2021-04-21 22:13:37.226981-07', '4eaf14e6-aa65-4cbf-a827-3c026666b6ac', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('4f344352-d72d-4145-ac62-b65c6cf70a68', '2021-04-21 22:14:21.167611-07', '750d81c9-c0ad-40e3-960c-f649ba1c3fe8', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('f2478c88-bf2b-49be-be51-c96b4f2d6530', '2021-04-21 22:14:21.528547-07', '750d81c9-c0ad-40e3-960c-f649ba1c3fe8', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('bae1cb8f-7810-41ec-b7e0-d448bce75c59', '2021-04-21 22:14:38.781024-07', '0280392e-282c-48aa-8db6-dd16c0e2e618', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('510ab1f5-50cc-48fd-92e0-6107b16ce5cf', '2021-04-21 22:14:38.973771-07', '0280392e-282c-48aa-8db6-dd16c0e2e618', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('0a9bc4cd-7d2b-48b6-b7cc-301ae685c80a', '2021-04-21 22:14:58.057009-07', '2e624f15-b7ad-4666-9f72-7623d8f14525', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('2dc38661-901f-4fb8-9616-e08b0ac986f9', '2021-04-21 22:14:58.223869-07', '2e624f15-b7ad-4666-9f72-7623d8f14525', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('237e83f3-a065-4eb8-a59b-1597faea3d20', '2021-04-21 22:15:45.624062-07', '05ef6115-8ba1-48a9-8c76-93d376cfb52a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('fca1083e-e2d8-46af-a054-735ff909c4be', '2021-04-21 22:15:45.972731-07', '05ef6115-8ba1-48a9-8c76-93d376cfb52a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('8c4ba375-a46c-49b7-b639-8f153ea63c75', '2021-04-21 22:16:08.67935-07', '6fa43269-4d73-40f2-8948-6ea27311263a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('92b413af-aadf-457d-8fd2-45d332471446', '2021-04-21 22:16:08.828159-07', '6fa43269-4d73-40f2-8948-6ea27311263a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('050c919c-dcc1-4413-a177-1fb527ec9860', '2021-04-21 22:16:36.247629-07', 'bdda3a68-28f5-4986-9b35-2c121f9d7b99', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('d21c08af-5182-4ded-8a29-562509946458', '2021-04-21 22:16:36.393218-07', 'bdda3a68-28f5-4986-9b35-2c121f9d7b99', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('ccdf0415-6123-49c5-ae1e-61563c22a296', '2021-04-21 22:21:30.473174-07', 'e77fce2c-05c4-47b6-8fe5-c7d4bcadbbdb', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('35802f86-216b-424a-9fe7-64676fd99f01', '2021-04-21 22:21:30.568735-07', 'e77fce2c-05c4-47b6-8fe5-c7d4bcadbbdb', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('3db2848e-6350-4199-817f-905fd92141f0', '2021-04-21 22:21:33.651045-07', '1c918c64-0d46-46f5-ada3-1422833e46a9', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('eb67c949-4a7e-4521-a083-a4650e216e7f', '2021-04-21 22:21:33.738845-07', '1c918c64-0d46-46f5-ada3-1422833e46a9', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('90dc8329-8973-46b0-944d-bd3bfaef437b', '2021-04-21 22:22:29.098984-07', '67d5beb5-3428-4338-ba36-051e5ff114c2', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('390d91ae-a341-4138-883f-9bc80295e871', '2021-04-21 22:22:29.190177-07', '67d5beb5-3428-4338-ba36-051e5ff114c2', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('ab624fce-5eaf-43bc-8a8d-127a16177e3f', '2021-04-21 22:22:31.359241-07', '835588fe-d7d6-4d60-a88f-b575df315d1a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('2bcb863f-43d4-419d-bf73-3ac174fc07c2', '2021-04-21 22:22:31.525423-07', '835588fe-d7d6-4d60-a88f-b575df315d1a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('ebd8de2b-53e6-451a-8345-fb9f49777dd3', '2021-04-21 22:24:22.446205-07', 'a39152fd-3222-4a9c-b71a-71670f68691f', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('5d721e80-257d-41a2-917f-4f2f9b96d21c', '2021-04-21 22:24:22.547325-07', 'a39152fd-3222-4a9c-b71a-71670f68691f', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('55c6cd4d-07b0-4dfd-b5f8-61b8fb95926f', '2021-04-21 22:24:24.396291-07', 'cbcd158b-7165-4487-adaa-fe4bfbffb7b9', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('ffa554d6-49b0-4657-a2e5-7b4c1a8d803e', '2021-04-21 22:24:24.466676-07', 'cbcd158b-7165-4487-adaa-fe4bfbffb7b9', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('c596005b-f525-4219-8707-db1ac3b0f347', '2021-04-21 22:24:59.520492-07', '612cee8a-efeb-42fb-b28a-1410899aa880', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('54083561-e1b4-4c54-b923-8432491e4980', '2021-04-21 22:24:59.648237-07', '612cee8a-efeb-42fb-b28a-1410899aa880', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('296fe4c7-cfa0-49e0-8184-3ef9c9efd53c', '2021-04-21 22:25:01.862289-07', '4e590458-e206-4b4e-b176-14f1a257c8cf', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('241df679-c52d-4963-b9c6-3fda17df61ea', '2021-04-21 22:25:01.933465-07', '4e590458-e206-4b4e-b176-14f1a257c8cf', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('3781da65-47cc-43ee-a5f2-f6a199b18ad7', '2021-04-21 22:25:42.107577-07', '1bb4cb32-a472-4040-8e5e-857ff844e226', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('11a3e567-6088-444f-8963-c46f2d4f1a89', '2021-04-21 22:25:42.282928-07', '1bb4cb32-a472-4040-8e5e-857ff844e226', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('0843be1d-dc60-4e69-9c9e-ef91ee69306b', '2021-04-21 22:25:42.913537-07', '6c2508c2-3704-442e-ad15-cbabf937fa07', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('fd4c285e-dc0e-4b23-bac8-7036a6dc364f', '2021-04-21 22:25:43.009764-07', '6c2508c2-3704-442e-ad15-cbabf937fa07', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('be2fe82d-9e8e-448b-a944-6ec12a3699fb', '2021-04-21 22:26:21.647424-07', '48990de4-fb2a-46f6-be92-46c976f50aff', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('4713808e-2c56-47a4-b3be-1d731756fb1d', '2021-04-21 22:26:21.771873-07', '48990de4-fb2a-46f6-be92-46c976f50aff', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('486f0b83-d53a-4610-8f9e-814843765ca5', '2021-04-21 22:26:23.570665-07', 'f657e640-d0ad-4f94-877c-6932b155d0f8', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('9f91cfcd-ef03-4ded-a031-d93bbaaf2713', '2021-04-21 22:26:23.693951-07', 'f657e640-d0ad-4f94-877c-6932b155d0f8', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('fe043b8d-6c11-4268-adc0-8aa5920e4663', '2021-04-21 22:31:39.700753-07', '9919837a-c835-4080-be66-0027717aae64', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('e0e84c72-a68b-4eb8-8144-d793f8b2eb61', '2021-04-21 22:31:39.84106-07', '9919837a-c835-4080-be66-0027717aae64', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('b99fd732-5636-44ba-b04c-486537bc0f7f', '2021-04-21 22:31:47.498268-07', '8f8fffef-a962-4129-a33f-97c138292757', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('44207c10-3e2a-4c41-94bb-e3328a1ac6fd', '2021-04-21 22:31:47.635976-07', '8f8fffef-a962-4129-a33f-97c138292757', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('a00c3b27-efb7-4537-8efc-1a819dc050d9', '2021-04-21 22:31:51.869169-07', '5eaa1d4f-0196-4454-ba08-7daf116bda0a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('c60982cc-aba2-49aa-9557-df01561cbcd0', '2021-04-21 22:31:51.957217-07', '5eaa1d4f-0196-4454-ba08-7daf116bda0a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('58872db0-f739-4787-9155-30a70906205e', '2021-04-21 22:31:58.003676-07', '1f74555a-e079-479f-a187-3faeb0b8a98a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('0974cfdf-dd4a-4490-aebf-736d92a51353', '2021-04-21 22:31:58.169217-07', '1f74555a-e079-479f-a187-3faeb0b8a98a', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('368755db-cfad-40f5-a661-75eeeadf754c', '2021-04-21 22:32:06.050625-07', '37459926-0d0f-423d-bc50-acf39bf15cd7', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('62651a7a-dc85-4dc2-8bd5-9f830a936d4f', '2021-04-21 22:32:06.186239-07', '37459926-0d0f-423d-bc50-acf39bf15cd7', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');
INSERT INTO public.file_status VALUES ('b2a92897-a0ec-404a-8622-fe42f7f0d8ec', '2021-04-21 22:32:43.308748-07', 'b82b6316-132d-4ce1-9b26-88942d1c2774', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Started', '');
INSERT INTO public.file_status VALUES ('0c5ad7a0-2921-4ef7-9466-ae4c343d72ce', '2021-04-21 22:32:43.460324-07', 'b82b6316-132d-4ce1-9b26-88942d1c2774', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'upload', 'Success', '');


--
-- Data for Name: files; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.files VALUES ('2cba5510-86dc-419c-a3ee-43db07e9b2d6', '2021-02-02 04:18:46.593207-08', 'test-file-path', 'test-file-name', '');
INSERT INTO public.files VALUES ('ff0c3d02-ba8e-48fc-838b-b40b04f39dbc', '2021-02-02 04:19:11.061124-08', 'test-file-path-2', 'test-file-name-2', '');
INSERT INTO public.files VALUES ('c46c960e-803c-4716-8803-d9673404a020', '2021-04-21 22:07:00.717146-07', 'playlist/69bb879e-fde5-4549-9cf7-d90c22207af5/tile - Bass Party Spotify Playlist Cover.jpg', 'Bass Party Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('915899f6-c1e8-449e-be12-d98e1c17bb70', '2021-04-21 22:07:26.587906-07', 'playlist/9f2df54d-f5f2-4192-b63f-878990857703/tile - Dance Anthems Spotify Playlist Cover.jpg', 'Dance Anthems Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('c4e8ea82-05a0-4015-b0f1-0a8bf4b81b8a', '2021-04-21 22:07:47.959203-07', 'playlist/ecff3731-79cc-41f9-a355-839b5065231f/tile - Deep House Spotify Playlist Cover.png', 'Deep House Spotify Playlist Cover.png', '');
INSERT INTO public.files VALUES ('00f1b4d5-28db-4c62-852f-dbf20542cc44', '2021-04-21 22:10:50.320996-07', 'playlist/e3536c6e-42f3-4193-a5ac-fe480b2221fa/tile - MSS Spotify Playlist Cover.jpg', 'MSS Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('71f3e46c-17c4-4253-a218-cbd9ef867961', '2021-04-21 22:12:50.122292-07', 'playlist/6476fd90-8b48-4dd7-8ae8-1ee7e39e5ad4/tile - Gaming Spotify Playlist Cover.jpg', 'Gaming Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('b97b5a5e-e11e-4e1b-9dfe-7ac7e9b739c4', '2021-04-21 22:13:17.785136-07', 'playlist/2207d12c-b579-4522-a0b6-cdf494ab955e/tile - Progressive House Spotify Playlist Cover.jpg', 'Progressive House Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('4eaf14e6-aa65-4cbf-a827-3c026666b6ac', '2021-04-21 22:13:37.025514-07', 'playlist/9a2c6f4e-81dd-431c-a71d-956266f2b1e5/tile - Pumped Up EDM Spotify Playlist Cover.jpg', 'Pumped Up EDM Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('750d81c9-c0ad-40e3-960c-f649ba1c3fe8', '2021-04-21 22:14:21.164335-07', 'playlist/39ab9ef7-b23d-49d7-8f89-f15834954aa6/tile - Radio Yonder Spotify Playlist Cover.jpg', 'Radio Yonder Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('0280392e-282c-48aa-8db6-dd16c0e2e618', '2021-04-21 22:14:38.77738-07', 'playlist/b430c9a7-a3af-4cdd-a606-1efae2a0f0c9/tile - Relaxing Electronic Spotify Playlist Cover.jpg', 'Relaxing Electronic Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('2e624f15-b7ad-4666-9f72-7623d8f14525', '2021-04-21 22:14:58.054401-07', 'playlist/92b73dcc-f5f0-45c9-ae20-941d2706cba8/tile - Roblox Spotify Playlist Cover.jpg', 'Roblox Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('05ef6115-8ba1-48a9-8c76-93d376cfb52a', '2021-04-21 22:15:45.620971-07', 'playlist/b1425bd9-bd2e-4224-a84e-a68dab27d70e/tile - Rocket League Spotify Playlist Cover.jpg', 'Rocket League Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('6fa43269-4d73-40f2-8948-6ea27311263a', '2021-04-21 22:16:08.675747-07', 'playlist/05c7e249-74e1-4794-bf43-376fc19191cb/tile - Silk New Releases Spotify Playlist Cover.jpg', 'Silk New Releases Spotify Playlist Cover.jpg', '');
INSERT INTO public.files VALUES ('bdda3a68-28f5-4986-9b35-2c121f9d7b99', '2021-04-21 22:16:36.244387-07', 'playlist/986b2a8b-be30-478c-a431-4fb8b6c1c110/tile - Summertime House Spotify Playlist Cover 2021.jpg', 'Summertime House Spotify Playlist Cover 2021.jpg', '');
INSERT INTO public.files VALUES ('e77fce2c-05c4-47b6-8fe5-c7d4bcadbbdb', '2021-04-21 22:21:30.470136-07', 'mood/f1e57895-6a7f-40bd-9172-ab0a0678dd14/tile - tile - chill-cover.jpg', 'tile - chill-cover.jpg', '');
INSERT INTO public.files VALUES ('1c918c64-0d46-46f5-ada3-1422833e46a9', '2021-04-21 22:21:33.648205-07', 'mood/f1e57895-6a7f-40bd-9172-ab0a0678dd14/background - background - chill-banner.jpg', 'background - chill-banner.jpg', '');
INSERT INTO public.files VALUES ('67d5beb5-3428-4338-ba36-051e5ff114c2', '2021-04-21 22:22:29.096164-07', 'mood/37876ed5-c4f0-483e-a64d-3ba85170475e/tile - tile - good-vibes-cover.jpg', 'tile - good-vibes-cover.jpg', '');
INSERT INTO public.files VALUES ('835588fe-d7d6-4d60-a88f-b575df315d1a', '2021-04-21 22:22:31.356249-07', 'mood/37876ed5-c4f0-483e-a64d-3ba85170475e/background - background - vibes-banner.jpg', 'background - vibes-banner.jpg', '');
INSERT INTO public.files VALUES ('a39152fd-3222-4a9c-b71a-71670f68691f', '2021-04-21 22:24:22.44112-07', 'mood/33d278fd-a812-46e7-8d2f-205ea4ad4f83/tile - tile - 1337-cover.jpg', 'tile - 1337-cover.jpg', '');
INSERT INTO public.files VALUES ('cbcd158b-7165-4487-adaa-fe4bfbffb7b9', '2021-04-21 22:24:24.393653-07', 'mood/33d278fd-a812-46e7-8d2f-205ea4ad4f83/background - background - 1337-banner.jpg', 'background - 1337-banner.jpg', '');
INSERT INTO public.files VALUES ('612cee8a-efeb-42fb-b28a-1410899aa880', '2021-04-21 22:24:59.517146-07', 'mood/b92413a1-d788-4167-86ff-af513b5e20b6/background - background - amped-banner.jpg', 'background - amped-banner.jpg', '');
INSERT INTO public.files VALUES ('4e590458-e206-4b4e-b176-14f1a257c8cf', '2021-04-21 22:25:01.857281-07', 'mood/b92413a1-d788-4167-86ff-af513b5e20b6/tile - tile - amped-cover.jpg', 'tile - amped-cover.jpg', '');
INSERT INTO public.files VALUES ('1bb4cb32-a472-4040-8e5e-857ff844e226', '2021-04-21 22:25:42.104448-07', 'mood/da29ace3-54fc-4442-a361-0539e0222cbc/background - background - footwork-banner.jpg', 'background - footwork-banner.jpg', '');
INSERT INTO public.files VALUES ('6c2508c2-3704-442e-ad15-cbabf937fa07', '2021-04-21 22:25:42.910197-07', 'mood/da29ace3-54fc-4442-a361-0539e0222cbc/tile - tile - footwork-cover.jpg', 'tile - footwork-cover.jpg', '');
INSERT INTO public.files VALUES ('48990de4-fb2a-46f6-be92-46c976f50aff', '2021-04-21 22:26:21.644579-07', 'mood/3ef2b38b-5cbe-47be-818a-a355bdf600bb/tile - tile - popped-cover.jpg', 'tile - popped-cover.jpg', '');
INSERT INTO public.files VALUES ('f657e640-d0ad-4f94-877c-6932b155d0f8', '2021-04-21 22:26:23.567877-07', 'mood/3ef2b38b-5cbe-47be-818a-a355bdf600bb/background - background - popped-banner.jpg', 'background - popped-banner.jpg', '');
INSERT INTO public.files VALUES ('9919837a-c835-4080-be66-0027717aae64', '2021-04-21 22:31:39.696329-07', 'playlist/69bb879e-fde5-4549-9cf7-d90c22207af5/tile - EDDIE - Waiting (Art)-min.jpg', 'EDDIE - Waiting (Art)-min.jpg', '');
INSERT INTO public.files VALUES ('8f8fffef-a962-4129-a33f-97c138292757', '2021-04-21 22:31:47.495914-07', 'playlist/9f2df54d-f5f2-4192-b63f-878990857703/tile - Eptic - Payback (Art)-min.jpg', 'Eptic - Payback (Art)-min.jpg', '');
INSERT INTO public.files VALUES ('5eaa1d4f-0196-4454-ba08-7daf116bda0a', '2021-04-21 22:31:51.866628-07', 'playlist/39ab9ef7-b23d-49d7-8f89-f15834954aa6/tile - Kohmi & KinAhau - Blink (Art)-min.jpg', 'Kohmi & KinAhau - Blink (Art)-min.jpg', '');
INSERT INTO public.files VALUES ('1f74555a-e079-479f-a187-3faeb0b8a98a', '2021-04-21 22:31:58.000407-07', 'playlist/2207d12c-b579-4522-a0b6-cdf494ab955e/tile - Tokyo Machine & Weird Genius - Last Summer (feat. Lights) (Art)-min.jpg', 'Tokyo Machine & Weird Genius - Last Summer (feat. Lights) (Art)-min.jpg', '');
INSERT INTO public.files VALUES ('37459926-0d0f-423d-bc50-acf39bf15cd7', '2021-04-21 22:32:06.046528-07', 'playlist/9a2c6f4e-81dd-431c-a71d-956266f2b1e5/tile - Curbi - Vertigo feat. Pollyanna (Art).jpg', 'Curbi - Vertigo feat. Pollyanna (Art).jpg', '');
INSERT INTO public.files VALUES ('b82b6316-132d-4ce1-9b26-88942d1c2774', '2021-04-21 22:32:43.305568-07', 'playlist/9f2df54d-f5f2-4192-b63f-878990857703/tile - AK - Back Again Album Art-min.jpg', 'AK - Back Again Album Art-min.jpg', '');
INSERT INTO public.files VALUES ('94ff8d9d-acb6-49be-b212-c8e703b6f8e9', '2021-06-25 12:24:08.897248-07', 'article/b5d54d18-4877-4add-8224-275a7b9c483b/cover-constellations.png', 'The_Lost_Civilization_Constellations_all.png', 'image/png');
INSERT INTO public.files VALUES ('54e49391-ac15-494e-9621-c6c894570a40', '2021-07-09 10:28:33.24728-07', 'article/b5d54d18-4877-4add-8224-275a7b9c483b/cover-cover-press-release-img-4.webp', 'press-release-img-4.webp', 'image/webp');
INSERT INTO public.files VALUES ('104c2a6b-5912-4c88-9c9b-f77fc604f444', '2021-07-09 10:28:40.136126-07', 'article/b5d54d18-4877-4add-8224-275a7b9c483b/cover-cover-press-release-img-3.webp', 'press-release-img-3.webp', 'image/webp');
INSERT INTO public.files VALUES ('2b665fa9-cd6b-4f46-a2ff-1c695f0c7a34', '2021-07-09 10:28:40.736784-07', 'article/b5d54d18-4877-4add-8224-275a7b9c483b/cover-cover-press-release-img-2.webp', 'press-release-img-2.webp', 'image/webp');
INSERT INTO public.files VALUES ('0c1a0b44-d1f7-4cb9-aa13-48d726f957e6', '2021-07-09 10:28:41.015197-07', 'article/b5d54d18-4877-4add-8224-275a7b9c483b/cover-cover-press-release-img-1.webp', 'press-release-img-1.webp', 'image/webp');


--
-- Data for Name: gold_stats; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.gold_stats VALUES (17566, 14551, 3845, 2088, 3527, 232, 139, 18078, 4077, 2227, 9681, 8185, 1496, 3302, 1499, 1803, 8429, 1496, 6933, 139875, 44869, 10216, 33910, 14349, 6686, 7663, '2019-12-02 03:00:08.019-08');
INSERT INTO public.gold_stats VALUES (17567, 14551, 3845, 2088, 3527, 232, 139, 18078, 4077, 2227, 9681, 8185, 1496, 3302, 1499, 1803, 8429, 1496, 6933, 139875, 44869, 10216, 33910, 14349, 6686, 7663, '2019-12-02 03:00:08.482-08');
INSERT INTO public.gold_stats VALUES (17568, 14551, 3846, 2091, 3527, 232, 139, 18078, 4078, 2230, 9678, 8183, 1495, 3302, 1498, 1804, 8429, 1495, 6934, 139877, 44871, 10221, 33909, 14349, 6685, 7664, '2019-12-02 04:00:08.613-08');
INSERT INTO public.gold_stats VALUES (17569, 14551, 3846, 2091, 3527, 232, 139, 18078, 4078, 2230, 9678, 8183, 1495, 3302, 1498, 1804, 8429, 1495, 6934, 139877, 44871, 10221, 33909, 14349, 6685, 7664, '2019-12-02 04:00:08.712-08');
INSERT INTO public.gold_stats VALUES (17570, 14550, 3847, 2091, 3527, 232, 139, 18077, 4079, 2230, 9676, 8182, 1494, 3302, 1497, 1805, 8429, 1494, 6935, 139879, 44875, 10223, 33910, 14349, 6685, 7664, '2019-12-02 05:00:07.562-08');
INSERT INTO public.gold_stats VALUES (17571, 14550, 3847, 2091, 3527, 232, 139, 18077, 4079, 2230, 9676, 8182, 1494, 3302, 1497, 1805, 8429, 1494, 6935, 139879, 44875, 10223, 33910, 14349, 6685, 7664, '2019-12-02 05:00:27.51-08');
INSERT INTO public.gold_stats VALUES (17572, 14549, 3848, 2087, 3527, 232, 139, 18076, 4080, 2226, 9674, 8181, 1493, 3302, 1496, 1806, 8429, 1493, 6936, 139883, 44876, 10221, 33913, 14349, 6685, 7664, '2019-12-02 06:00:08.4-08');
INSERT INTO public.gold_stats VALUES (17573, 14549, 3848, 2087, 3527, 232, 139, 18076, 4080, 2226, 9674, 8181, 1493, 3302, 1496, 1806, 8429, 1493, 6936, 139883, 44876, 10221, 33913, 14349, 6685, 7664, '2019-12-02 06:00:08.544-08');
INSERT INTO public.gold_stats VALUES (17574, 14550, 3849, 2092, 3527, 231, 138, 18077, 4080, 2230, 9673, 8182, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139884, 44877, 10226, 33910, 14350, 6686, 7664, '2019-12-02 07:00:06.953-08');
INSERT INTO public.gold_stats VALUES (17575, 14550, 3849, 2092, 3527, 231, 138, 18077, 4080, 2230, 9673, 8182, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139884, 44877, 10226, 33910, 14350, 6686, 7664, '2019-12-02 07:00:07.63-08');
INSERT INTO public.gold_stats VALUES (17576, 14550, 3849, 2094, 3527, 231, 138, 18077, 4080, 2232, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139884, 44878, 10226, 33910, 14351, 6687, 7664, '2019-12-02 08:00:07.878-08');
INSERT INTO public.gold_stats VALUES (17577, 14550, 3849, 2094, 3527, 231, 138, 18077, 4080, 2232, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139884, 44878, 10226, 33910, 14351, 6687, 7664, '2019-12-02 08:00:08.229-08');
INSERT INTO public.gold_stats VALUES (17578, 14550, 3849, 2094, 3527, 231, 138, 18077, 4080, 2232, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139884, 44878, 10222, 33914, 14351, 6687, 7664, '2019-12-02 09:00:07.84-08');
INSERT INTO public.gold_stats VALUES (17579, 14550, 3849, 2094, 3527, 231, 138, 18077, 4080, 2232, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139884, 44878, 10222, 33914, 14351, 6687, 7664, '2019-12-02 09:00:08.432-08');
INSERT INTO public.gold_stats VALUES (17580, 14550, 3848, 2092, 3527, 231, 137, 18077, 4079, 2229, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139885, 44878, 10221, 33915, 14351, 6687, 7664, '2019-12-02 10:00:07.549-08');
INSERT INTO public.gold_stats VALUES (17581, 14550, 3848, 2092, 3527, 231, 137, 18077, 4079, 2229, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139885, 44878, 10221, 33915, 14351, 6687, 7664, '2019-12-02 10:00:23.627-08');
INSERT INTO public.gold_stats VALUES (17582, 14548, 3847, 2093, 3527, 231, 137, 18075, 4078, 2230, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139886, 44878, 10225, 33911, 14351, 6687, 7664, '2019-12-02 11:00:07.726-08');
INSERT INTO public.gold_stats VALUES (17583, 14548, 3847, 2093, 3527, 231, 137, 18075, 4078, 2230, 9674, 8183, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139886, 44878, 10225, 33911, 14351, 6687, 7664, '2019-12-02 11:00:07.861-08');
INSERT INTO public.gold_stats VALUES (17584, 14548, 3846, 2095, 3527, 230, 137, 18075, 4076, 2232, 9673, 8182, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139889, 44878, 10225, 33911, 14351, 6686, 7665, '2019-12-02 12:00:07.914-08');
INSERT INTO public.gold_stats VALUES (17585, 14548, 3846, 2095, 3527, 230, 137, 18075, 4076, 2232, 9673, 8182, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139889, 44878, 10225, 33911, 14351, 6686, 7665, '2019-12-02 12:00:07.987-08');
INSERT INTO public.gold_stats VALUES (17586, 14552, 3850, 2096, 3527, 230, 137, 18079, 4080, 2233, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139893, 44881, 10219, 33914, 14355, 6690, 7665, '2019-12-02 13:00:08.984-08');
INSERT INTO public.gold_stats VALUES (17587, 14552, 3850, 2096, 3527, 230, 137, 18079, 4080, 2233, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139893, 44881, 10219, 33914, 14355, 6690, 7665, '2019-12-02 13:00:09.106-08');
INSERT INTO public.gold_stats VALUES (17588, 14552, 3850, 2095, 3527, 230, 137, 18079, 4080, 2232, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139894, 44882, 10214, 33914, 14355, 6690, 7665, '2019-12-02 14:00:07.574-08');
INSERT INTO public.gold_stats VALUES (17589, 14552, 3850, 2095, 3527, 230, 137, 18079, 4080, 2232, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139894, 44882, 10214, 33914, 14355, 6690, 7665, '2019-12-02 14:00:08.04-08');
INSERT INTO public.gold_stats VALUES (17590, 14552, 3848, 2094, 3527, 230, 137, 18079, 4078, 2231, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139895, 44882, 10215, 33914, 14355, 6690, 7665, '2019-12-02 15:00:07.206-08');
INSERT INTO public.gold_stats VALUES (17591, 14552, 3848, 2094, 3527, 230, 137, 18079, 4078, 2231, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139895, 44882, 10215, 33914, 14355, 6690, 7665, '2019-12-02 15:00:13.219-08');
INSERT INTO public.gold_stats VALUES (17592, 14551, 3849, 2089, 3527, 230, 137, 18078, 4079, 2226, 9676, 8185, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139897, 44884, 10206, 33915, 14355, 6689, 7666, '2019-12-02 16:00:07.845-08');
INSERT INTO public.gold_stats VALUES (17593, 14551, 3849, 2089, 3527, 230, 137, 18078, 4079, 2226, 9676, 8185, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139897, 44884, 10206, 33915, 14355, 6689, 7666, '2019-12-02 16:00:07.94-08');
INSERT INTO public.gold_stats VALUES (17594, 14552, 3852, 2088, 3527, 230, 135, 18079, 4082, 2223, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139898, 44886, 10211, 33917, 14357, 6690, 7667, '2019-12-02 17:00:08.212-08');
INSERT INTO public.gold_stats VALUES (17595, 14552, 3852, 2088, 3527, 230, 135, 18079, 4082, 2223, 9677, 8186, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139898, 44886, 10211, 33917, 14357, 6690, 7667, '2019-12-02 17:00:29.516-08');
INSERT INTO public.gold_stats VALUES (17596, 14552, 3851, 2085, 3527, 230, 135, 18079, 4081, 2220, 9676, 8185, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139899, 44887, 10210, 33920, 14358, 6689, 7669, '2019-12-02 18:00:08.312-08');
INSERT INTO public.gold_stats VALUES (17597, 14552, 3851, 2085, 3527, 230, 135, 18079, 4081, 2220, 9676, 8185, 1491, 3302, 1496, 1806, 8429, 1491, 6938, 139899, 44887, 10210, 33920, 14358, 6689, 7669, '2019-12-02 18:00:08.551-08');
INSERT INTO public.gold_stats VALUES (17598, 14553, 3855, 2085, 3527, 230, 133, 18080, 4085, 2218, 9673, 8183, 1490, 3302, 1496, 1806, 8429, 1490, 6939, 139901, 44891, 10210, 33925, 14358, 6687, 7671, '2019-12-02 19:00:07.971-08');
INSERT INTO public.gold_stats VALUES (17599, 14553, 3855, 2085, 3527, 230, 133, 18080, 4085, 2218, 9673, 8183, 1490, 3302, 1496, 1806, 8429, 1490, 6939, 139901, 44891, 10210, 33925, 14358, 6687, 7671, '2019-12-02 19:00:08.5-08');
INSERT INTO public.gold_stats VALUES (17600, 14551, 3857, 2080, 3527, 231, 134, 18078, 4088, 2214, 9668, 8180, 1488, 3302, 1496, 1806, 8429, 1488, 6941, 139903, 44891, 10215, 33924, 14358, 6684, 7674, '2019-12-02 20:00:07.506-08');
INSERT INTO public.gold_stats VALUES (17601, 14551, 3857, 2080, 3527, 231, 134, 18078, 4088, 2214, 9668, 8180, 1488, 3302, 1496, 1806, 8429, 1488, 6941, 139903, 44891, 10215, 33924, 14358, 6684, 7674, '2019-12-02 20:00:08.567-08');
INSERT INTO public.gold_stats VALUES (17602, 14552, 3853, 2074, 3527, 230, 133, 18079, 4083, 2207, 9668, 8181, 1487, 3302, 1496, 1806, 8429, 1487, 6942, 139904, 44894, 10212, 33924, 14359, 6685, 7674, '2019-12-02 21:00:10.133-08');
INSERT INTO public.gold_stats VALUES (17603, 14552, 3853, 2074, 3527, 230, 133, 18079, 4083, 2207, 9668, 8181, 1487, 3302, 1496, 1806, 8429, 1487, 6942, 139904, 44894, 10212, 33924, 14359, 6685, 7674, '2019-12-02 21:00:10.184-08');
INSERT INTO public.gold_stats VALUES (17604, 14555, 3853, 2067, 3527, 230, 134, 18082, 4083, 2201, 9671, 8184, 1487, 3302, 1495, 1807, 8429, 1487, 6942, 139908, 44895, 10213, 33922, 14363, 6689, 7674, '2019-12-02 22:00:06.905-08');
INSERT INTO public.gold_stats VALUES (17605, 14555, 3853, 2067, 3527, 230, 134, 18082, 4083, 2201, 9671, 8184, 1487, 3302, 1495, 1807, 8429, 1487, 6942, 139908, 44895, 10213, 33922, 14363, 6689, 7674, '2019-12-02 22:00:11.547-08');
INSERT INTO public.gold_stats VALUES (17606, 14556, 3850, 2066, 3527, 231, 133, 18083, 4081, 2199, 9672, 8185, 1487, 3302, 1495, 1807, 8429, 1487, 6942, 139908, 44895, 10213, 33922, 14364, 6690, 7674, '2019-12-02 23:00:08.956-08');
INSERT INTO public.gold_stats VALUES (17607, 14556, 3850, 2066, 3527, 231, 133, 18083, 4081, 2199, 9672, 8185, 1487, 3302, 1495, 1807, 8429, 1487, 6942, 139908, 44895, 10213, 33922, 14364, 6690, 7674, '2019-12-02 23:00:23.063-08');
INSERT INTO public.gold_stats VALUES (17608, 14556, 3846, 2067, 3527, 231, 132, 18083, 4077, 2199, 9671, 8185, 1486, 3302, 1495, 1807, 8429, 1486, 6943, 139908, 44896, 10208, 33924, 14364, 6690, 7674, '2019-12-03 00:00:09.529-08');
INSERT INTO public.gold_stats VALUES (17609, 14556, 3846, 2067, 3527, 231, 132, 18083, 4077, 2199, 9671, 8185, 1486, 3302, 1495, 1807, 8429, 1486, 6943, 139908, 44896, 10208, 33924, 14364, 6690, 7674, '2019-12-03 00:00:09.555-08');
INSERT INTO public.gold_stats VALUES (17610, 14556, 3849, 2065, 3527, 231, 134, 18083, 4080, 2199, 9671, 8186, 1485, 3302, 1495, 1807, 8429, 1485, 6944, 139912, 44896, 10215, 33923, 14365, 6691, 7674, '2019-12-03 01:00:06.84-08');
INSERT INTO public.gold_stats VALUES (17611, 14556, 3849, 2064, 3527, 230, 134, 18083, 4079, 2198, 9671, 8186, 1485, 3302, 1495, 1807, 8429, 1485, 6944, 139912, 44896, 10215, 33923, 14365, 6691, 7674, '2019-12-03 01:00:30.338-08');
INSERT INTO public.gold_stats VALUES (17612, 14557, 3848, 2070, 3527, 230, 133, 18084, 4078, 2203, 9670, 8185, 1485, 3302, 1495, 1807, 8429, 1485, 6944, 139913, 44899, 10223, 33927, 14366, 6690, 7676, '2019-12-03 02:00:07.11-08');
INSERT INTO public.gold_stats VALUES (17613, 14557, 3848, 2070, 3527, 230, 133, 18084, 4078, 2203, 9670, 8185, 1485, 3302, 1495, 1807, 8429, 1485, 6944, 139913, 44899, 10223, 33927, 14366, 6690, 7676, '2019-12-03 02:00:07.191-08');
INSERT INTO public.gold_stats VALUES (17614, 14559, 3851, 2082, 3527, 230, 133, 18086, 4081, 2215, 9672, 8188, 1484, 3302, 1495, 1807, 8429, 1484, 6945, 139914, 44899, 10228, 33926, 14369, 6693, 7676, '2019-12-03 03:00:07.026-08');
INSERT INTO public.gold_stats VALUES (17615, 14559, 3851, 2082, 3527, 230, 133, 18086, 4081, 2215, 9672, 8188, 1484, 3302, 1495, 1807, 8429, 1484, 6945, 139914, 44899, 10228, 33926, 14369, 6693, 7676, '2019-12-03 03:00:11.289-08');
INSERT INTO public.gold_stats VALUES (17616, 14560, 3852, 2082, 3527, 230, 133, 18087, 4082, 2215, 9673, 8189, 1484, 3302, 1495, 1807, 8429, 1484, 6945, 139915, 44900, 10230, 33926, 14370, 6694, 7676, '2019-12-03 04:00:08.873-08');
INSERT INTO public.gold_stats VALUES (17617, 14560, 3852, 2082, 3527, 230, 133, 18087, 4082, 2215, 9673, 8189, 1484, 3302, 1495, 1807, 8429, 1484, 6945, 139915, 44900, 10230, 33926, 14370, 6694, 7676, '2019-12-03 04:00:09.158-08');
INSERT INTO public.gold_stats VALUES (17618, 14560, 3854, 2083, 3527, 230, 131, 18087, 4084, 2214, 9673, 8189, 1484, 3302, 1495, 1807, 8429, 1484, 6945, 139917, 44901, 10230, 33925, 14370, 6694, 7676, '2019-12-03 05:00:08.35-08');
INSERT INTO public.gold_stats VALUES (17619, 14560, 3854, 2083, 3527, 230, 131, 18087, 4084, 2214, 9673, 8189, 1484, 3302, 1495, 1807, 8429, 1484, 6945, 139917, 44901, 10230, 33925, 14370, 6694, 7676, '2019-12-03 05:00:08.926-08');
INSERT INTO public.gold_stats VALUES (17620, 14563, 3858, 2082, 3527, 230, 130, 18090, 4088, 2212, 9674, 8191, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139918, 44901, 10229, 33926, 14373, 6696, 7677, '2019-12-03 06:00:07.312-08');
INSERT INTO public.gold_stats VALUES (17621, 14563, 3858, 2082, 3527, 230, 130, 18090, 4088, 2212, 9674, 8191, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139918, 44901, 10228, 33927, 14373, 6696, 7677, '2019-12-03 06:00:28.444-08');
INSERT INTO public.gold_stats VALUES (17622, 14564, 3857, 2084, 3527, 230, 131, 18091, 4087, 2215, 9675, 8192, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139920, 44903, 10231, 33926, 14374, 6697, 7677, '2019-12-03 07:00:08.521-08');
INSERT INTO public.gold_stats VALUES (17623, 14564, 3857, 2084, 3527, 230, 131, 18091, 4087, 2215, 9675, 8192, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139920, 44903, 10231, 33926, 14374, 6697, 7677, '2019-12-03 07:00:08.673-08');
INSERT INTO public.gold_stats VALUES (17624, 14564, 3857, 2086, 3527, 230, 131, 18091, 4087, 2217, 9675, 8192, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139922, 44904, 10232, 33927, 14374, 6697, 7677, '2019-12-03 08:00:06.337-08');
INSERT INTO public.gold_stats VALUES (17625, 14564, 3857, 2086, 3527, 230, 131, 18091, 4087, 2217, 9675, 8192, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139922, 44904, 10232, 33927, 14374, 6697, 7677, '2019-12-03 08:00:23.589-08');
INSERT INTO public.gold_stats VALUES (17626, 14564, 3859, 2086, 3527, 230, 131, 18091, 4089, 2217, 9675, 8192, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139923, 44905, 10235, 33927, 14376, 6697, 7679, '2019-12-03 09:00:08.376-08');
INSERT INTO public.gold_stats VALUES (17627, 14564, 3859, 2086, 3527, 230, 131, 18091, 4089, 2217, 9675, 8192, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139923, 44905, 10235, 33927, 14376, 6697, 7679, '2019-12-03 09:00:08.568-08');
INSERT INTO public.gold_stats VALUES (17628, 14566, 3856, 2084, 3527, 230, 131, 18093, 4086, 2215, 9677, 8194, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139927, 44906, 10232, 33930, 14378, 6699, 7679, '2019-12-03 10:00:06.574-08');
INSERT INTO public.gold_stats VALUES (17629, 14566, 3856, 2084, 3527, 230, 131, 18093, 4086, 2215, 9677, 8194, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139927, 44906, 10232, 33930, 14378, 6699, 7679, '2019-12-03 10:00:08.086-08');
INSERT INTO public.gold_stats VALUES (17630, 14567, 3854, 2084, 3527, 230, 131, 18094, 4084, 2215, 9677, 8194, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139929, 44909, 10235, 33927, 14379, 6699, 7680, '2019-12-03 11:00:06.602-08');
INSERT INTO public.gold_stats VALUES (17631, 14567, 3854, 2083, 3527, 230, 131, 18094, 4084, 2214, 9677, 8194, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139929, 44909, 10235, 33927, 14379, 6699, 7680, '2019-12-03 11:00:32.327-08');
INSERT INTO public.gold_stats VALUES (17632, 14568, 3856, 2086, 3527, 230, 130, 18095, 4086, 2216, 9678, 8195, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139931, 44910, 10235, 33927, 14380, 6700, 7680, '2019-12-03 12:00:08.707-08');
INSERT INTO public.gold_stats VALUES (17633, 14568, 3856, 2086, 3527, 230, 130, 18095, 4086, 2216, 9678, 8195, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139931, 44910, 10235, 33927, 14380, 6700, 7680, '2019-12-03 12:00:08.734-08');
INSERT INTO public.gold_stats VALUES (17634, 14571, 3859, 2089, 3527, 230, 130, 18098, 4089, 2219, 9680, 8197, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139934, 44911, 10233, 33931, 14383, 6702, 7681, '2019-12-03 13:00:08.024-08');
INSERT INTO public.gold_stats VALUES (17635, 14571, 3859, 2089, 3527, 230, 130, 18098, 4089, 2219, 9680, 8197, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139934, 44911, 10233, 33931, 14383, 6702, 7681, '2019-12-03 13:00:08.11-08');
INSERT INTO public.gold_stats VALUES (17636, 14571, 3860, 2090, 3527, 230, 130, 18098, 4090, 2220, 9679, 8196, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139935, 44912, 10233, 33935, 14383, 6701, 7682, '2019-12-03 14:00:07.702-08');
INSERT INTO public.gold_stats VALUES (17637, 14571, 3860, 2090, 3527, 230, 130, 18098, 4090, 2220, 9679, 8196, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139935, 44912, 10233, 33935, 14383, 6701, 7682, '2019-12-03 14:00:07.861-08');
INSERT INTO public.gold_stats VALUES (17638, 14570, 3858, 2092, 3527, 230, 130, 18097, 4088, 2222, 9680, 8197, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139937, 44913, 10240, 33932, 14384, 6702, 7682, '2019-12-03 15:00:08.54-08');
INSERT INTO public.gold_stats VALUES (17639, 14570, 3858, 2092, 3527, 230, 130, 18097, 4088, 2222, 9680, 8197, 1483, 3302, 1495, 1807, 8429, 1483, 6946, 139937, 44913, 10240, 33932, 14384, 6702, 7682, '2019-12-03 15:00:13.87-08');
INSERT INTO public.gold_stats VALUES (17640, 14571, 3860, 2094, 3527, 229, 129, 18098, 4089, 2223, 9679, 8197, 1482, 3302, 1495, 1807, 8429, 1482, 6947, 139940, 44914, 10234, 33932, 14386, 6702, 7684, '2019-12-03 16:00:07.828-08');
INSERT INTO public.gold_stats VALUES (17641, 14571, 3860, 2094, 3527, 229, 129, 18098, 4089, 2223, 9679, 8197, 1482, 3302, 1495, 1807, 8429, 1482, 6947, 139940, 44914, 10234, 33932, 14386, 6702, 7684, '2019-12-03 16:00:08.402-08');
INSERT INTO public.gold_stats VALUES (17642, 14574, 3864, 2096, 3527, 229, 129, 18101, 4093, 2225, 9681, 8199, 1482, 3302, 1495, 1807, 8429, 1482, 6947, 139942, 44915, 10237, 33933, 14391, 6704, 7687, '2019-12-03 17:00:08.534-08');
INSERT INTO public.gold_stats VALUES (17643, 14574, 3864, 2096, 3527, 229, 129, 18101, 4093, 2225, 9681, 8199, 1482, 3302, 1495, 1807, 8429, 1482, 6947, 139942, 44915, 10237, 33933, 14391, 6704, 7687, '2019-12-03 17:00:09.69-08');
INSERT INTO public.gold_stats VALUES (17644, 14574, 3861, 2092, 3527, 229, 130, 18101, 4090, 2222, 9680, 8199, 1481, 3302, 1495, 1807, 8429, 1481, 6948, 139942, 44915, 10239, 33934, 14391, 6704, 7687, '2019-12-03 18:00:07.172-08');
INSERT INTO public.gold_stats VALUES (17645, 14574, 3861, 2092, 3527, 229, 130, 18101, 4090, 2222, 9680, 8199, 1481, 3302, 1495, 1807, 8429, 1481, 6948, 139942, 44915, 10239, 33934, 14391, 6704, 7687, '2019-12-03 18:00:29.115-08');
INSERT INTO public.gold_stats VALUES (17646, 14573, 3861, 2094, 3527, 229, 130, 18100, 4090, 2224, 9679, 8198, 1481, 3302, 1495, 1807, 8429, 1481, 6948, 139943, 44918, 10237, 33936, 14391, 6703, 7688, '2019-12-03 19:00:07.655-08');
INSERT INTO public.gold_stats VALUES (17647, 14573, 3861, 2094, 3527, 229, 130, 18100, 4090, 2224, 9679, 8198, 1481, 3302, 1495, 1807, 8429, 1481, 6948, 139943, 44918, 10237, 33936, 14391, 6703, 7688, '2019-12-03 19:00:07.822-08');
INSERT INTO public.gold_stats VALUES (17648, 14573, 3860, 2096, 3527, 230, 131, 18100, 4090, 2227, 9680, 8199, 1481, 3302, 1495, 1807, 8429, 1481, 6948, 139945, 44919, 10246, 33933, 14392, 6704, 7688, '2019-12-03 20:00:08.328-08');
INSERT INTO public.gold_stats VALUES (17649, 14573, 3860, 2096, 3527, 230, 131, 18100, 4090, 2227, 9680, 8199, 1481, 3302, 1495, 1807, 8429, 1481, 6948, 139945, 44919, 10246, 33933, 14392, 6704, 7688, '2019-12-03 20:00:09.083-08');
INSERT INTO public.gold_stats VALUES (17650, 14568, 3872, 2130, 3527, 238, 140, 18095, 4110, 2270, 9676, 8196, 1480, 3302, 1494, 1808, 8429, 1480, 6949, 140216, 44921, 10243, 33931, 14393, 6702, 7691, '2019-12-03 21:00:09.595-08');
INSERT INTO public.gold_stats VALUES (17651, 14568, 3872, 2130, 3527, 238, 140, 18095, 4110, 2270, 9676, 8196, 1480, 3302, 1494, 1808, 8429, 1480, 6949, 140216, 44921, 10243, 33931, 14393, 6702, 7691, '2019-12-03 21:00:09.788-08');
INSERT INTO public.gold_stats VALUES (17652, 14565, 3878, 2142, 3527, 242, 143, 18092, 4120, 2285, 9677, 8197, 1480, 3302, 1493, 1809, 8429, 1480, 6949, 140540, 44925, 10245, 33936, 14396, 6704, 7692, '2019-12-03 22:00:09.119-08');
INSERT INTO public.gold_stats VALUES (17653, 14565, 3878, 2142, 3527, 242, 143, 18092, 4120, 2285, 9677, 8197, 1480, 3302, 1493, 1809, 8429, 1480, 6949, 140540, 44925, 10245, 33936, 14396, 6704, 7692, '2019-12-03 22:00:09.306-08');
INSERT INTO public.gold_stats VALUES (17654, 14563, 3883, 2154, 3527, 245, 145, 18090, 4128, 2299, 9679, 8199, 1480, 3302, 1493, 1809, 8429, 1480, 6949, 140868, 44925, 10241, 33938, 14398, 6706, 7692, '2019-12-03 23:00:06.949-08');
INSERT INTO public.gold_stats VALUES (17655, 14563, 3883, 2154, 3527, 245, 145, 18090, 4128, 2299, 9679, 8199, 1480, 3302, 1493, 1809, 8429, 1480, 6949, 140868, 44925, 10241, 33938, 14398, 6706, 7692, '2019-12-03 23:00:11.647-08');
INSERT INTO public.gold_stats VALUES (17656, 14565, 3891, 2166, 3527, 247, 148, 18092, 4138, 2314, 9681, 8201, 1480, 3302, 1493, 1809, 8429, 1480, 6949, 141062, 44928, 10246, 33938, 14402, 6708, 7694, '2019-12-04 00:00:09.32-08');
INSERT INTO public.gold_stats VALUES (17657, 14565, 3891, 2166, 3527, 247, 148, 18092, 4138, 2314, 9681, 8201, 1480, 3302, 1493, 1809, 8429, 1480, 6949, 141062, 44928, 10246, 33938, 14402, 6708, 7694, '2019-12-04 00:00:09.619-08');
INSERT INTO public.gold_stats VALUES (17658, 14563, 3895, 2171, 3527, 248, 150, 18090, 4143, 2321, 9680, 8200, 1480, 3302, 1492, 1810, 8429, 1480, 6949, 141218, 44929, 10262, 33937, 14402, 6708, 7694, '2019-12-04 01:00:08.534-08');
INSERT INTO public.gold_stats VALUES (17659, 14563, 3895, 2171, 3527, 248, 150, 18090, 4143, 2321, 9680, 8200, 1480, 3302, 1492, 1810, 8429, 1480, 6949, 141218, 44929, 10262, 33937, 14402, 6708, 7694, '2019-12-04 01:00:08.81-08');
INSERT INTO public.gold_stats VALUES (17660, 14561, 3900, 2179, 3527, 249, 150, 18088, 4149, 2329, 9681, 8201, 1480, 3302, 1492, 1810, 8429, 1480, 6949, 141441, 44930, 10265, 33938, 14403, 6709, 7694, '2019-12-04 02:00:08.219-08');
INSERT INTO public.gold_stats VALUES (17661, 14561, 3900, 2179, 3527, 249, 150, 18088, 4149, 2329, 9681, 8201, 1480, 3302, 1492, 1810, 8429, 1480, 6949, 141441, 44930, 10265, 33938, 14403, 6709, 7694, '2019-12-04 02:00:08.234-08');
INSERT INTO public.gold_stats VALUES (17662, 14562, 3899, 2184, 3527, 249, 150, 18089, 4148, 2334, 9681, 8202, 1479, 3302, 1491, 1811, 8429, 1479, 6950, 141622, 44935, 10264, 33939, 14405, 6711, 7694, '2019-12-04 03:00:07.773-08');
INSERT INTO public.gold_stats VALUES (17663, 14562, 3899, 2184, 3527, 249, 150, 18089, 4148, 2334, 9681, 8202, 1479, 3302, 1491, 1811, 8429, 1479, 6950, 141622, 44935, 10264, 33939, 14405, 6711, 7694, '2019-12-04 03:00:07.853-08');
INSERT INTO public.gold_stats VALUES (17664, 14560, 3897, 2184, 3527, 248, 150, 18087, 4145, 2334, 9679, 8201, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 141798, 44938, 10263, 33939, 14405, 6710, 7695, '2019-12-04 04:00:08.36-08');
INSERT INTO public.gold_stats VALUES (17665, 14560, 3897, 2184, 3527, 248, 150, 18087, 4145, 2334, 9679, 8201, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 141798, 44938, 10263, 33939, 14405, 6710, 7695, '2019-12-04 04:00:08.467-08');
INSERT INTO public.gold_stats VALUES (17666, 14559, 3898, 2187, 3527, 248, 150, 18086, 4146, 2337, 9680, 8202, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 141903, 44938, 10269, 33937, 14406, 6711, 7695, '2019-12-04 05:00:08.551-08');
INSERT INTO public.gold_stats VALUES (17667, 14559, 3898, 2187, 3527, 248, 150, 18086, 4146, 2337, 9680, 8202, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 141903, 44938, 10269, 33937, 14406, 6711, 7695, '2019-12-04 05:00:09.378-08');
INSERT INTO public.gold_stats VALUES (17668, 14560, 3897, 2189, 3527, 248, 151, 18087, 4145, 2340, 9681, 8203, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142006, 44938, 10268, 33938, 14407, 6712, 7695, '2019-12-04 06:00:07.793-08');
INSERT INTO public.gold_stats VALUES (17669, 14560, 3897, 2189, 3527, 248, 151, 18087, 4145, 2340, 9681, 8203, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142006, 44938, 10268, 33938, 14407, 6712, 7695, '2019-12-04 06:00:08.376-08');
INSERT INTO public.gold_stats VALUES (17670, 14558, 3900, 2192, 3527, 248, 150, 18085, 4148, 2342, 9681, 8203, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142092, 44938, 10266, 33938, 14407, 6712, 7695, '2019-12-04 07:00:07.582-08');
INSERT INTO public.gold_stats VALUES (17671, 14558, 3900, 2192, 3527, 248, 150, 18085, 4148, 2342, 9681, 8203, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142092, 44938, 10266, 33938, 14407, 6712, 7695, '2019-12-04 07:00:07.587-08');
INSERT INTO public.gold_stats VALUES (17672, 14560, 3904, 2198, 3527, 249, 151, 18087, 4153, 2349, 9685, 8207, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142145, 44943, 10270, 33938, 14411, 6716, 7695, '2019-12-04 08:00:07.885-08');
INSERT INTO public.gold_stats VALUES (17673, 14560, 3904, 2198, 3527, 249, 151, 18087, 4153, 2349, 9685, 8207, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142145, 44943, 10270, 33938, 14411, 6716, 7695, '2019-12-04 08:00:07.951-08');
INSERT INTO public.gold_stats VALUES (17674, 14560, 3904, 2197, 3527, 250, 152, 18087, 4154, 2349, 9685, 8207, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142200, 44943, 10267, 33941, 14411, 6716, 7695, '2019-12-04 09:00:07.278-08');
INSERT INTO public.gold_stats VALUES (17675, 14560, 3904, 2197, 3527, 250, 152, 18087, 4154, 2349, 9685, 8207, 1478, 3302, 1491, 1811, 8429, 1478, 6951, 142200, 44943, 10267, 33941, 14411, 6716, 7695, '2019-12-04 09:00:11.976-08');
INSERT INTO public.gold_stats VALUES (17676, 14559, 3904, 2202, 3527, 250, 152, 18086, 4154, 2354, 9683, 8206, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142293, 44943, 10268, 33939, 14411, 6715, 7696, '2019-12-04 10:00:07.769-08');
INSERT INTO public.gold_stats VALUES (17677, 14559, 3904, 2202, 3527, 250, 152, 18086, 4154, 2354, 9683, 8206, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142293, 44943, 10268, 33939, 14411, 6715, 7696, '2019-12-04 10:00:29.756-08');
INSERT INTO public.gold_stats VALUES (17678, 14560, 3904, 2204, 3527, 251, 152, 18087, 4155, 2356, 9684, 8207, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142358, 44944, 10274, 33939, 14412, 6716, 7696, '2019-12-04 11:00:07.562-08');
INSERT INTO public.gold_stats VALUES (17679, 14560, 3904, 2204, 3527, 251, 152, 18087, 4155, 2356, 9684, 8207, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142359, 44944, 10274, 33939, 14412, 6716, 7696, '2019-12-04 11:00:28.806-08');
INSERT INTO public.gold_stats VALUES (17680, 14558, 3902, 2204, 3527, 251, 153, 18085, 4153, 2357, 9683, 8206, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142435, 44945, 10270, 33940, 14412, 6715, 7697, '2019-12-04 12:00:09.696-08');
INSERT INTO public.gold_stats VALUES (17681, 14558, 3902, 2204, 3527, 251, 153, 18085, 4153, 2357, 9683, 8206, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142435, 44945, 10270, 33940, 14412, 6715, 7697, '2019-12-04 12:00:09.808-08');
INSERT INTO public.gold_stats VALUES (17682, 14557, 3903, 2203, 3527, 251, 151, 18084, 4154, 2354, 9682, 8205, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142533, 44947, 10271, 33939, 14413, 6714, 7699, '2019-12-04 13:00:07.461-08');
INSERT INTO public.gold_stats VALUES (17683, 14557, 3903, 2203, 3527, 251, 151, 18084, 4154, 2354, 9682, 8205, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142533, 44947, 10271, 33939, 14413, 6714, 7699, '2019-12-04 13:00:12.726-08');
INSERT INTO public.gold_stats VALUES (17684, 14556, 3899, 2205, 3527, 251, 151, 18083, 4150, 2356, 9681, 8204, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142618, 44949, 10269, 33939, 14413, 6713, 7700, '2019-12-04 14:00:07.966-08');
INSERT INTO public.gold_stats VALUES (17685, 14556, 3899, 2205, 3527, 251, 151, 18083, 4150, 2356, 9681, 8204, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142618, 44949, 10269, 33939, 14413, 6713, 7700, '2019-12-04 14:00:09.304-08');
INSERT INTO public.gold_stats VALUES (17686, 14556, 3905, 2214, 3527, 252, 152, 18083, 4157, 2366, 9682, 8205, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142813, 44949, 10269, 33939, 14415, 6714, 7701, '2019-12-04 15:00:07.076-08');
INSERT INTO public.gold_stats VALUES (17687, 14556, 3905, 2214, 3527, 252, 152, 18083, 4157, 2366, 9682, 8205, 1477, 3302, 1491, 1811, 8429, 1477, 6952, 142813, 44949, 10269, 33939, 14415, 6714, 7701, '2019-12-04 15:00:24.081-08');
INSERT INTO public.gold_stats VALUES (17688, 14555, 3903, 2219, 3527, 252, 152, 18082, 4155, 2371, 9683, 8206, 1477, 3302, 1490, 1812, 8429, 1477, 6952, 142959, 44949, 10252, 33942, 14417, 6716, 7701, '2019-12-04 16:00:07.93-08');
INSERT INTO public.gold_stats VALUES (17689, 14555, 3903, 2219, 3527, 252, 152, 18082, 4155, 2371, 9683, 8206, 1477, 3302, 1490, 1812, 8429, 1477, 6952, 142959, 44949, 10252, 33942, 14417, 6716, 7701, '2019-12-04 16:00:22.558-08');
INSERT INTO public.gold_stats VALUES (17690, 14557, 3910, 2225, 3527, 252, 152, 18084, 4162, 2377, 9685, 8208, 1477, 3302, 1490, 1812, 8429, 1477, 6952, 143083, 44950, 10271, 33939, 14419, 6718, 7701, '2019-12-04 17:00:06.466-08');
INSERT INTO public.gold_stats VALUES (17691, 14557, 3910, 2225, 3527, 252, 152, 18084, 4162, 2377, 9685, 8208, 1477, 3302, 1490, 1812, 8429, 1477, 6952, 143083, 44950, 10271, 33939, 14419, 6718, 7701, '2019-12-04 17:00:08.124-08');
INSERT INTO public.gold_stats VALUES (17692, 14554, 3909, 2221, 3527, 252, 151, 18081, 4161, 2372, 9682, 8206, 1476, 3302, 1490, 1812, 8429, 1476, 6953, 143220, 44951, 10274, 33938, 14419, 6716, 7703, '2019-12-04 18:00:08.515-08');
INSERT INTO public.gold_stats VALUES (17693, 14554, 3909, 2221, 3527, 252, 151, 18081, 4161, 2372, 9682, 8206, 1476, 3302, 1490, 1812, 8429, 1476, 6953, 143220, 44951, 10274, 33938, 14419, 6716, 7703, '2019-12-04 18:00:10.283-08');
INSERT INTO public.gold_stats VALUES (17694, 14552, 3908, 2224, 3527, 252, 153, 18079, 4160, 2377, 9679, 8204, 1475, 3302, 1490, 1812, 8429, 1475, 6954, 143447, 44951, 10263, 33940, 14419, 6714, 7705, '2019-12-04 19:00:08.845-08');
INSERT INTO public.gold_stats VALUES (17695, 14552, 3908, 2224, 3527, 252, 153, 18079, 4160, 2377, 9679, 8204, 1475, 3302, 1490, 1812, 8429, 1475, 6954, 143447, 44951, 10263, 33940, 14419, 6714, 7705, '2019-12-04 19:00:09.04-08');
INSERT INTO public.gold_stats VALUES (17696, 14554, 3908, 2222, 3527, 252, 154, 18081, 4160, 2376, 9679, 8204, 1475, 3302, 1490, 1812, 8429, 1475, 6954, 143606, 44953, 10261, 33945, 14421, 6714, 7707, '2019-12-04 20:00:07.376-08');
INSERT INTO public.gold_stats VALUES (17697, 14554, 3908, 2222, 3527, 252, 154, 18081, 4160, 2376, 9679, 8204, 1475, 3302, 1490, 1812, 8429, 1475, 6954, 143606, 44953, 10261, 33945, 14421, 6714, 7707, '2019-12-04 20:00:07.404-08');
INSERT INTO public.gold_stats VALUES (17698, 14555, 3915, 2224, 3527, 252, 154, 18082, 4167, 2378, 9681, 8206, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 143778, 44955, 10272, 33941, 14424, 6717, 7707, '2019-12-04 21:00:08.999-08');
INSERT INTO public.gold_stats VALUES (17699, 14555, 3915, 2224, 3527, 252, 154, 18082, 4167, 2378, 9681, 8206, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 143778, 44955, 10272, 33941, 14424, 6717, 7707, '2019-12-04 21:00:09.057-08');
INSERT INTO public.gold_stats VALUES (17700, 14557, 3914, 2222, 3527, 253, 153, 18084, 4167, 2375, 9683, 8208, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 143922, 44960, 10274, 33943, 14426, 6719, 7707, '2019-12-04 22:00:08.079-08');
INSERT INTO public.gold_stats VALUES (17701, 14557, 3914, 2222, 3527, 253, 153, 18084, 4167, 2375, 9683, 8208, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 143923, 44960, 10274, 33943, 14426, 6719, 7707, '2019-12-04 22:00:08.409-08');
INSERT INTO public.gold_stats VALUES (17702, 14556, 3910, 2218, 3527, 253, 151, 18083, 4163, 2369, 9683, 8208, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 144018, 44961, 10278, 33946, 14426, 6719, 7707, '2019-12-04 23:00:07.95-08');
INSERT INTO public.gold_stats VALUES (17703, 14556, 3910, 2218, 3527, 253, 151, 18083, 4163, 2369, 9683, 8208, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 144018, 44961, 10278, 33946, 14426, 6719, 7707, '2019-12-04 23:00:08.031-08');
INSERT INTO public.gold_stats VALUES (17704, 14556, 3910, 2221, 3527, 254, 152, 18083, 4164, 2373, 9682, 8207, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 144142, 44966, 10280, 33946, 14426, 6718, 7708, '2019-12-05 00:00:08.975-08');
INSERT INTO public.gold_stats VALUES (17705, 14556, 3910, 2221, 3527, 254, 152, 18083, 4164, 2373, 9682, 8207, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 144142, 44966, 10280, 33946, 14426, 6718, 7708, '2019-12-05 00:00:09.17-08');
INSERT INTO public.gold_stats VALUES (17706, 14558, 3911, 2223, 3527, 254, 153, 18085, 4165, 2376, 9684, 8209, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 144286, 44967, 10283, 33945, 14428, 6720, 7708, '2019-12-05 01:00:07.968-08');
INSERT INTO public.gold_stats VALUES (17707, 14558, 3911, 2223, 3527, 254, 153, 18085, 4165, 2376, 9684, 8209, 1475, 3302, 1489, 1813, 8429, 1475, 6954, 144286, 44967, 10283, 33945, 14428, 6720, 7708, '2019-12-05 01:00:08.227-08');
INSERT INTO public.gold_stats VALUES (17708, 14558, 3911, 2228, 3527, 255, 153, 18085, 4166, 2381, 9683, 8208, 1475, 3302, 1488, 1814, 8429, 1475, 6954, 144374, 44971, 10277, 33952, 14429, 6720, 7709, '2019-12-05 02:00:08.113-08');
INSERT INTO public.gold_stats VALUES (17709, 14558, 3911, 2228, 3527, 255, 153, 18085, 4166, 2381, 9683, 8208, 1475, 3302, 1488, 1814, 8429, 1475, 6954, 144374, 44971, 10277, 33952, 14429, 6720, 7709, '2019-12-05 02:00:08.447-08');
INSERT INTO public.gold_stats VALUES (17710, 14556, 3905, 2224, 3527, 254, 153, 18083, 4159, 2377, 9680, 8207, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144458, 44973, 10277, 33950, 14429, 6719, 7710, '2019-12-05 03:00:08.205-08');
INSERT INTO public.gold_stats VALUES (17711, 14556, 3905, 2224, 3527, 254, 153, 18083, 4159, 2377, 9680, 8207, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144458, 44973, 10277, 33950, 14429, 6719, 7710, '2019-12-05 03:00:08.751-08');
INSERT INTO public.gold_stats VALUES (17712, 14556, 3910, 2235, 3527, 254, 153, 18083, 4164, 2388, 9680, 8207, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144570, 44971, 10282, 33947, 14430, 6719, 7711, '2019-12-05 04:00:08.059-08');
INSERT INTO public.gold_stats VALUES (17713, 14556, 3910, 2235, 3527, 254, 153, 18083, 4164, 2388, 9680, 8207, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144570, 44971, 10282, 33947, 14430, 6719, 7711, '2019-12-05 04:00:09.326-08');
INSERT INTO public.gold_stats VALUES (17714, 14557, 3908, 2230, 3527, 254, 153, 18084, 4162, 2383, 9681, 8208, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144676, 44971, 10277, 33948, 14431, 6720, 7711, '2019-12-05 05:00:07.112-08');
INSERT INTO public.gold_stats VALUES (17715, 14557, 3908, 2230, 3527, 254, 153, 18084, 4162, 2383, 9681, 8208, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144676, 44971, 10277, 33948, 14431, 6720, 7711, '2019-12-05 05:00:28.488-08');
INSERT INTO public.gold_stats VALUES (17716, 14557, 3907, 2229, 3527, 255, 155, 18084, 4162, 2384, 9680, 8207, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144738, 44973, 10275, 33955, 14431, 6719, 7712, '2019-12-05 06:00:06.984-08');
INSERT INTO public.gold_stats VALUES (17717, 14557, 3907, 2229, 3527, 255, 155, 18084, 4162, 2384, 9680, 8207, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144738, 44973, 10275, 33955, 14431, 6719, 7712, '2019-12-05 06:00:16.081-08');
INSERT INTO public.gold_stats VALUES (17718, 14559, 3906, 2228, 3527, 255, 155, 18086, 4161, 2383, 9682, 8209, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144813, 44971, 10285, 33954, 14433, 6721, 7712, '2019-12-05 07:00:08.613-08');
INSERT INTO public.gold_stats VALUES (17719, 14559, 3906, 2228, 3527, 255, 155, 18086, 4161, 2383, 9682, 8209, 1473, 3302, 1488, 1814, 8429, 1473, 6956, 144813, 44971, 10285, 33954, 14433, 6721, 7712, '2019-12-05 07:00:08.874-08');
INSERT INTO public.gold_stats VALUES (17720, 14560, 3904, 2226, 3527, 255, 155, 18087, 4159, 2381, 9680, 8208, 1472, 3302, 1488, 1814, 8429, 1472, 6957, 144863, 44972, 10283, 33953, 14434, 6720, 7714, '2019-12-05 08:00:08.28-08');
INSERT INTO public.gold_stats VALUES (17721, 14560, 3904, 2226, 3527, 255, 155, 18087, 4159, 2381, 9680, 8208, 1472, 3302, 1488, 1814, 8429, 1472, 6957, 144863, 44972, 10283, 33953, 14434, 6720, 7714, '2019-12-05 08:00:08.899-08');
INSERT INTO public.gold_stats VALUES (17722, 14560, 3903, 2227, 3527, 255, 155, 18087, 4158, 2382, 9680, 8208, 1472, 3302, 1488, 1814, 8429, 1472, 6957, 144913, 44974, 10281, 33956, 14434, 6720, 7714, '2019-12-05 09:00:07.164-08');
INSERT INTO public.gold_stats VALUES (17723, 14560, 3903, 2227, 3527, 255, 155, 18087, 4158, 2382, 9680, 8208, 1472, 3302, 1488, 1814, 8429, 1472, 6957, 144913, 44974, 10281, 33956, 14434, 6720, 7714, '2019-12-05 09:00:11.948-08');
INSERT INTO public.gold_stats VALUES (17724, 14560, 3903, 2227, 3527, 255, 155, 18087, 4158, 2382, 9679, 8207, 1472, 3302, 1487, 1815, 8429, 1472, 6957, 144942, 44975, 10285, 33953, 14434, 6720, 7714, '2019-12-05 10:00:07.084-08');
INSERT INTO public.gold_stats VALUES (17725, 14560, 3903, 2227, 3527, 255, 155, 18087, 4158, 2382, 9679, 8207, 1472, 3302, 1487, 1815, 8429, 1472, 6957, 144942, 44975, 10285, 33953, 14434, 6720, 7714, '2019-12-05 10:00:09.528-08');
INSERT INTO public.gold_stats VALUES (17726, 14561, 3905, 2230, 3527, 256, 156, 18088, 4161, 2386, 9680, 8208, 1472, 3302, 1487, 1815, 8429, 1472, 6957, 144992, 44977, 10278, 33953, 14435, 6721, 7714, '2019-12-05 11:00:07.356-08');
INSERT INTO public.gold_stats VALUES (17727, 14561, 3905, 2230, 3527, 256, 156, 18088, 4161, 2386, 9680, 8208, 1472, 3302, 1487, 1815, 8429, 1472, 6957, 144992, 44977, 10278, 33953, 14435, 6721, 7714, '2019-12-05 11:00:07.665-08');
INSERT INTO public.gold_stats VALUES (17728, 14562, 3904, 2232, 3527, 256, 155, 18089, 4160, 2387, 9681, 8209, 1472, 3302, 1486, 1816, 8429, 1472, 6957, 145033, 44976, 10280, 33953, 14437, 6723, 7714, '2019-12-05 12:00:07.866-08');
INSERT INTO public.gold_stats VALUES (17729, 14562, 3904, 2232, 3527, 256, 155, 18089, 4160, 2387, 9681, 8209, 1472, 3302, 1486, 1816, 8429, 1472, 6957, 145033, 44976, 10280, 33953, 14437, 6723, 7714, '2019-12-05 12:00:08.596-08');
INSERT INTO public.gold_stats VALUES (17730, 14562, 3903, 2236, 3527, 255, 155, 18089, 4158, 2391, 9680, 8209, 1471, 3302, 1486, 1816, 8429, 1471, 6958, 145083, 44977, 10284, 33952, 14437, 6723, 7714, '2019-12-05 13:00:08.642-08');
INSERT INTO public.gold_stats VALUES (17731, 14562, 3903, 2236, 3527, 255, 155, 18089, 4158, 2391, 9680, 8209, 1471, 3302, 1486, 1816, 8429, 1471, 6958, 145083, 44977, 10284, 33952, 14437, 6723, 7714, '2019-12-05 13:00:09.021-08');
INSERT INTO public.gold_stats VALUES (17732, 14563, 3905, 2237, 3527, 255, 157, 18090, 4160, 2394, 9680, 8209, 1471, 3302, 1486, 1816, 8429, 1471, 6958, 145133, 44978, 10286, 33955, 14439, 6723, 7716, '2019-12-05 14:00:08.515-08');
INSERT INTO public.gold_stats VALUES (17733, 14563, 3905, 2237, 3527, 255, 157, 18090, 4160, 2394, 9680, 8209, 1471, 3302, 1486, 1816, 8429, 1471, 6958, 145133, 44978, 10286, 33955, 14439, 6723, 7716, '2019-12-05 14:00:30.861-08');
INSERT INTO public.gold_stats VALUES (17734, 14563, 3906, 2238, 3527, 255, 158, 18090, 4161, 2396, 9679, 8208, 1471, 3302, 1486, 1816, 8429, 1471, 6958, 145194, 44983, 10290, 33956, 14440, 6722, 7718, '2019-12-05 15:00:09.189-08');
INSERT INTO public.gold_stats VALUES (17735, 14563, 3906, 2238, 3527, 255, 158, 18090, 4161, 2396, 9679, 8208, 1471, 3302, 1486, 1816, 8429, 1471, 6958, 145194, 44983, 10290, 33956, 14440, 6722, 7718, '2019-12-05 15:00:09.2-08');
INSERT INTO public.gold_stats VALUES (17736, 14563, 3906, 2240, 3527, 255, 158, 18090, 4161, 2398, 9678, 8208, 1470, 3302, 1486, 1816, 8429, 1470, 6959, 145267, 44984, 10280, 33957, 14440, 6722, 7718, '2019-12-05 16:00:07.622-08');
INSERT INTO public.gold_stats VALUES (17737, 14563, 3906, 2240, 3527, 255, 158, 18090, 4161, 2398, 9678, 8208, 1470, 3302, 1486, 1816, 8429, 1470, 6959, 145267, 44984, 10280, 33957, 14440, 6722, 7718, '2019-12-05 16:00:15.516-08');
INSERT INTO public.gold_stats VALUES (17738, 14562, 3905, 2244, 3527, 256, 158, 18089, 4161, 2402, 9679, 8209, 1470, 3302, 1486, 1816, 8429, 1470, 6959, 145374, 44987, 10282, 33959, 14441, 6723, 7718, '2019-12-05 17:00:09.379-08');
INSERT INTO public.gold_stats VALUES (17739, 14562, 3905, 2244, 3527, 256, 158, 18089, 4161, 2402, 9679, 8209, 1470, 3302, 1486, 1816, 8429, 1470, 6959, 145374, 44987, 10282, 33959, 14441, 6723, 7718, '2019-12-05 17:00:09.391-08');
INSERT INTO public.gold_stats VALUES (17740, 14563, 3906, 2248, 3527, 258, 160, 18090, 4164, 2408, 9680, 8210, 1470, 3302, 1486, 1816, 8429, 1470, 6959, 145451, 44987, 10284, 33956, 14442, 6724, 7718, '2019-12-05 18:00:08.345-08');
INSERT INTO public.gold_stats VALUES (17741, 14563, 3906, 2248, 3527, 258, 160, 18090, 4164, 2408, 9680, 8210, 1470, 3302, 1486, 1816, 8429, 1470, 6959, 145451, 44987, 10284, 33956, 14442, 6724, 7718, '2019-12-05 18:00:09.653-08');
INSERT INTO public.gold_stats VALUES (17742, 14564, 3907, 2254, 3527, 257, 158, 18091, 4164, 2412, 9679, 8209, 1470, 3302, 1485, 1817, 8429, 1470, 6959, 145537, 44990, 10279, 33959, 14444, 6724, 7720, '2019-12-05 19:00:07.419-08');
INSERT INTO public.gold_stats VALUES (17743, 14564, 3907, 2254, 3527, 257, 158, 18091, 4164, 2412, 9679, 8209, 1470, 3302, 1485, 1817, 8429, 1470, 6959, 145538, 44990, 10279, 33959, 14444, 6724, 7720, '2019-12-05 19:00:28.729-08');
INSERT INTO public.gold_stats VALUES (17744, 14566, 3908, 2260, 3527, 257, 158, 18093, 4165, 2418, 9678, 8212, 1466, 3302, 1485, 1817, 8429, 1466, 6963, 145581, 44992, 10272, 33960, 14447, 6727, 7720, '2019-12-05 20:00:07.753-08');
INSERT INTO public.gold_stats VALUES (17745, 14566, 3908, 2260, 3527, 257, 158, 18093, 4165, 2418, 9678, 8212, 1466, 3302, 1485, 1817, 8429, 1466, 6963, 145581, 44992, 10272, 33960, 14447, 6727, 7720, '2019-12-05 20:00:11.448-08');


--
-- Data for Name: gold_time_ranges; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.gold_time_ranges VALUES ('cc0d4bb4-26b9-4b89-99fd-0b6f0ee6492d', '2021-04-20 22:42:46.867767-07', 'cb81745f-ba7b-4f53-aafb-efe0b2a71e74', '{"legacy": true, "source": "legacy", "legacyGoldSubscriptionId": "57bb91d5ca1a377e7cfc7105"}', '', '2016-09-05 17:00:00-07', '2018-09-06 17:00:00-07');
INSERT INTO public.gold_time_ranges VALUES ('5d5f7f83-ccd8-4a49-ab62-0eb15970423f', '2021-04-20 22:42:46.867767-07', 'cb81745f-ba7b-4f53-aafb-efe0b2a71e74', '{"source": "PayPal Recurring Subscription", "subscriptionId": "I-2VE3YSELVP7U"}', '', '2018-11-05 23:47:04.728-08', '2018-12-05 18:00:00-08');
INSERT INTO public.gold_time_ranges VALUES ('532810da-0006-4fd7-97c4-6340a2fa5293', '2021-04-20 22:42:46.867767-07', '30a3fbc7-1db1-4659-ac0d-e54ce5855c3a', '{"source": "PayPal Recurring Subscription", "subscriptionId": "I-2VE3YSELVP7U"}', '', '2018-11-05 23:47:04.728-08', '2018-12-05 18:00:00-08');
INSERT INTO public.gold_time_ranges VALUES ('5153d707-024e-48ce-949b-5ba1a406c56d', '2021-04-20 22:42:46.867767-07', 'd47784de-03e8-4c69-81e5-4b02931082e8', NULL, '', '2021-04-20 21:42:46.867767-07', '2030-01-01 08:00:00-08');


--
-- Data for Name: gold_unsub_survey_results; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: homepage_slider; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: homepage_slider_item; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: http_sessions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.http_sessions VALUES (1, '\x35443353344a36364f42545737445048334e4d57445853533659414e4d56495450444e47354b41584b585643414b494651324d51', '\x4d54597a4e7a45784d7a597a4f58784564693143516b46465131383053554642556b464352554642515638355646396e5a304646516d354f4d474e74624856616433645951554a5765567058556d746857464630596a4a474d5752485a335269527a6c7157566853634749794e45646a4d314a3559566331626b524262304644517a6c365956646b6455785862485643626b3477593231736456703364324642516d68365956646b645578586248564d5745347857544a4f62474d7a54585269527a6c7157566853634749794e45646a4d314a3559566331626b524354554646557a6c6f59306472646c6b79526a425a56336832576e6b356257525865484e43626b3477593231736456703364306c4251567057597a4a5765564e585555646a4d314a3559566331626b52445755464b52305579546b644a4e4539585654464d56315a725458704a6445354553544261557a413157565243614578555758684e616b6b315455526e65453548566d6c4e5a3170365a45684b63474a74593031455155464c5647315762467049546c56694d6e5273596d6453615749794f584e425a306c425155453950587932516564756633675647394273545879613575487541537856662d6350677448326a55636a7832567a55773d3d', '2021-11-16 17:47:15.115496-08', '2021-11-16 17:47:19.521459-08', '2021-12-16 17:47:19.521458-08');
INSERT INTO public.http_sessions VALUES (2, '\x5a4945484c4550485456594a354a524f36515a57364e4932474b45544644513557524c47374f4d354936584d42344c3342494941', '\x4d54597a4e7a45784d7a59314d58784564693143516b46465131383053554642556b464352554642515752324c554e4251556c48597a4e53655746584e573545516d4e42526c684b62467048556e426b517a4632575668574d4746444d584e694d6b356f5a456473646d4a6e576e706b53457077596d316a54554e6e51556c4d4d303577576a4930644746584e45646a4d314a3559566331626b52436230464853453577576a4930644746584e48526a4d315a7157544a57656d4e354d584e694d6b356f5a456473646d4a6e576e706b53457077596d316a5455563351564a4d4d6b5a3359564d35616c6c59556d6869527a6c7554444a614d574a48647a3138434f665754384f6e7a454f3761324a51636c46554c4c4d6c4b363536696f637463584a7258746659464e6b3d', '2021-11-16 17:47:31.427636-08', '2021-11-16 17:47:31.427636-08', '2021-12-16 17:47:31.427636-08');
INSERT INTO public.http_sessions VALUES (3, '\x465051414f5a4241474552454f37364632344d46574b475a355043365032344735415845373659535a574b324547584a524e4c41', '\x4d54597a4e7a45784d7a59344d48784564693143516b46465131383053554642556b464352554642515752324c554e4251556c48597a4e53655746584e573545516d4e42526c684b62467048556e426b517a4632575668574d4746444d584e694d6b356f5a456473646d4a6e576e706b53457077596d316a54554e6e51556c4d4d303577576a4930644746584e45646a4d314a3559566331626b52436230464853453577576a4930644746584e48526a4d315a7157544a57656d4e354d584e694d6b356f5a456473646d4a6e576e706b53457077596d316a5455563351564a4d4d6b5a3359564d35616c6c59556d6869527a6c7554444a614d574a48647a31384c514a7a694472687632474e58383138745148697a7a6b656a7855676e61414355557867303561555679513d', '2021-11-16 17:48:00.122258-08', '2021-11-16 17:48:00.122258-08', '2021-12-16 17:48:00.122258-08');
INSERT INTO public.http_sessions VALUES (4, '\x514a354e47374b35444b3554464f4c4e37514833483232475755374e41524945595356554c424454324533495137584d59575151', '\x4d54597a4e7a45334e6a67334e33784564693143516b46465131383053554642556b46435255464251575a664c554e4251556c48597a4e53655746584e573545516d4e42526c684b62467048556e426b517a4632575668574d4746444d584e694d6b356f5a456473646d4a6e576e706b53457077596d316a54554e6e51556c4d4d303577576a4930644746584e45646a4d314a3559566331626b52436230464853453577576a4930644746584e48526a4d315a7157544a57656d4e354d584e694d6b356f5a456473646d4a6e576e706b53457077596d316a545568425157464d4d6b5a3359564d35616c6c59556d6869527a6c7554444a614d574a486431396a4d6a6c355a45517861474d79545431386c7a333259396a5f65376b4c33746561345257386d534b766b4967625349563350634e55442d50376e78733d', '2021-11-17 11:21:17.625698-08', '2021-11-17 11:21:17.625699-08', '2021-12-17 11:21:17.625698-08');
INSERT INTO public.http_sessions VALUES (5, '\x454854334e37494735443457513632593732465148514c424f434f544b4c4c464643374a5050434e5033534d364e34355a513541', '\x4d54597a4e7a45334e7a4d7a4d48784564693143516b46465131383053554642556b46435255464251566c324c554e4251556c48597a4e53655746584e57354551576442516d7857656c7059536b7061515670365a45684b63474a745930314b5a3046725756525a4d466c715a7a566156465630576c6452656b31704d44424e616c4a7354465273614531485258524f616b563554577072643039455254426156306c35516d354f4d474e74624856616433644e5155467754317058566d746a4d564a3259544a5764554a48536e5a694d6e644451576442515878543367715f5075686b514a767a3450714a45364d5a4e78545a312d6947346257565637692d6271777936413d3d', '2021-11-17 11:28:50.558852-08', '2021-11-17 11:28:50.558853-08', '2021-12-17 11:28:50.558852-08');
INSERT INTO public.http_sessions VALUES (6, '\x52424b59494e4b37585935524a465149323257464342535257463556325251474437524a5058573442553351475a435934435041', '\x4d54597a4e7a45344e5463784e6e784564693143516b46465131383053554642556b46435255464251563830626c396e5a304644516d354f4d474e74624856616433645951554a5765567058556d746857464630596a4a474d5752485a335269527a6c7157566853634749794e45646a4d314a3559566331626b524262304644517a6c365956646b6455785862485643626b3477593231736456703364324642516d68365956646b645578586248564d5745347857544a4f62474d7a54585269527a6c7157566853634749794e45646a4d314a3559566331626b52445755464b517a6c6f59306472646c6b79526a425a56336832576e6b356257525865484e514d303532593235524f566c59546d704b62586877596c64734d4642555258644e515430396647457a5369464a5138786c65416135536a6a59357050704f4c5f41526a316d59783041486d6d7375773238', '2021-11-17 13:48:36.617486-08', '2021-11-17 13:48:36.617486-08', '2021-12-17 13:48:36.617486-08');
INSERT INTO public.http_sessions VALUES (7, '\x37375749345035473551335542324b4451584355544c525833554d514c594641374b564c334f545933374a56414a4a5241494441', '\x4d54597a4e7a45344e546b324e58784564693143516b46465131383053554642556b46435255464251563830626c396e5a304644516d354f4d474e74624856616433645951554a5765567058556d746857464630596a4a474d5752485a335269527a6c7157566853634749794e45646a4d314a3559566331626b524262304644517a6c365956646b6455785862485643626b3477593231736456703364324642516d68365956646b645578586248564d5745347857544a4f62474d7a54585269527a6c7157566853634749794e45646a4d314a3559566331626b52445755464b517a6c6f59306472646c6b79526a425a56336832576e6b356257525865484e514d303532593235524f566c59546d704b62586877596c64734d4642555258644e5154303966477630393932365a316a644c6a79794a616e4b314d36734d4e5f367a545a38515f63616a785862364d344f', '2021-11-17 13:52:45.17778-08', '2021-11-17 13:52:45.17778-08', '2021-12-17 13:52:45.17778-08');
INSERT INTO public.http_sessions VALUES (8, '\x3253414d55545042585848494f34354b49574e4843514a424e414f505a47484b4633424a534c4d36375a4a45545050564d4a3551', '\x4d54597a4e7a45344e546b344e6e784564693143516b46465131383053554642556b46435255464251563830626c396e5a304644516d354f4d474e74624856616433645951554a5765567058556d746857464630596a4a474d5752485a335269527a6c7157566853634749794e45646a4d314a3559566331626b524262304644517a6c365956646b6455785862485643626b3477593231736456703364324642516d68365956646b645578586248564d5745347857544a4f62474d7a54585269527a6c7157566853634749794e45646a4d314a3559566331626b52445755464b517a6c6f59306472646c6b79526a425a56336832576e6b356257525865484e514d303532593235524f566c59546d704b62586877596c64734d4642555258644e5154303966416a2d79485a474d7a355f7275707839484167324561466b674f2d616a4e725167536a5f787151574b6b48', '2021-11-17 13:53:06.641866-08', '2021-11-17 13:53:06.641866-08', '2021-12-17 13:53:06.641866-08');
INSERT INTO public.http_sessions VALUES (9, '\x4b374c4c474b5a53485451593642424e46354f4b4c534a4f5037445455475a4c56574d3434454a4f324e574c5a554f4e56435151', '\x4d54597a4e7a45344e546b354e48784564693143516b46465131383053554642556b46435255464251563830626c396e5a304644516d354f4d474e74624856616433645951554a5765567058556d746857464630596a4a474d5752485a335269527a6c7157566853634749794e45646a4d314a3559566331626b524262304644517a6c365956646b6455785862485643626b3477593231736456703364324642516d68365956646b645578586248564d5745347857544a4f62474d7a54585269527a6c7157566853634749794e45646a4d314a3559566331626b52445755464b517a6c6f59306472646c6b79526a425a56336832576e6b356257525865484e514d303532593235524f566c59546d704b62586877596c64734d4642555258644e51543039664d42433057477472427939336449655a3234504a754d74626e3477616878656e4e4f535443477a386d4e32', '2021-11-17 13:53:14.257508-08', '2021-11-17 13:53:14.257508-08', '2021-12-17 13:53:14.257508-08');


--
-- Data for Name: license_access_tokens; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: license_time_ranges; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.license_time_ranges VALUES ('e292d5a4-c60b-4e91-b1e6-d9b0a4a84355', '2021-04-20 22:42:46.867767-07', '27a8a076-1652-4c11-8a88-515b4e049e9e', '2017-01-30 05:26:30.017348-08', '2050-02-15 05:26:30.017348-08', '', NULL);
INSERT INTO public.license_time_ranges VALUES ('d08e2b38-0b19-4c4d-b14a-918e00529697', '2021-04-20 22:42:46.867767-07', 'a9336053-ee8d-4a70-9f93-afab1c6b0f52', '2017-01-29 21:26:30.017348-08', '2019-02-14 21:26:30.017348-08', '', NULL);
INSERT INTO public.license_time_ranges VALUES ('15deea1d-987a-4ce7-a884-008b89a53dbf', '2021-04-20 22:42:46.867767-07', 'a9336053-ee8d-4a70-9f93-afab1c6b0f52', '2019-02-14 21:26:30.017348-08', '2019-03-14 21:26:30.017348-07', '', NULL);
INSERT INTO public.license_time_ranges VALUES ('079028b2-6a3d-4f16-8e75-686bed6ee930', '2021-04-20 22:42:46.867767-07', '63d4ee19-f4f9-4c43-b7d3-02b12ad716cc', '2020-01-02 21:26:30.017348-08', '2020-03-01 21:26:30.017348-08', '', NULL);
INSERT INTO public.license_time_ranges VALUES ('5fad7d67-54c8-4b68-bf7a-5a646ccb340b', '2021-04-20 22:42:46.867767-07', 'df68756d-8bdf-4b21-b277-e54e19a11c0c', '2018-12-15 05:26:30.017348-08', '2050-02-15 05:26:30.017348-08', '', NULL);
INSERT INTO public.license_time_ranges VALUES ('8268a7fb-8f05-43a4-a477-0baf997574a2', '2021-04-20 22:42:46.867767-07', 'b9adb1e7-9402-4324-b73f-49e09d8af3b5', '2018-01-15 05:26:30.017348-08', '2050-02-15 05:26:30.017348-08', '', NULL);
INSERT INTO public.license_time_ranges VALUES ('027f9824-f4ad-4b69-a298-ec3c078b780e', '2021-04-20 22:42:46.867767-07', 'df68756d-8bdf-4b21-b277-e54e19a11c0c', '2018-09-15 18:07:37-07', '2018-10-15 18:09:19-07', 'existing gold', NULL);
INSERT INTO public.license_time_ranges VALUES ('11ce49c2-707f-46e4-9e49-c86e77cefcd8', '2021-04-20 22:42:46.867767-07', 'df68756d-8bdf-4b21-b277-e54e19a11c0c', '2018-11-01 18:07:37-07', '2018-12-15 18:09:19-08', 'xsolla sub 5b9d4ad07734bf311d36e183', NULL);
INSERT INTO public.license_time_ranges VALUES ('8ad4da5c-b651-48df-a53e-977993df8975', '2021-04-20 22:42:46.867767-07', 'df68756d-8bdf-4b21-b277-e54e19a11c0c', '2018-12-15 17:09:19-08', '2019-01-15 18:09:19-08', 'xsolla sub 5b9d4ad07734bf311d36e183', NULL);


--
-- Data for Name: licenses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.licenses VALUES ('27a8a076-1652-4c11-8a88-515b4e049e9e', '2021-04-20 22:42:46.867767-07', 'UCqCSl8Eq_0by8ad7u5JNSOQ', '2021-04-20 22:42:46.867767-07', '', NULL, 'Auto', '2021-11-16 15:29:22.283511-08', 'YouTube', 'cb81745f-ba7b-4f53-aafb-efe0b2a71e74', false, 'Queued', true, true, 0, false, '', NULL, false, NULL);
INSERT INTO public.licenses VALUES ('958aae55-c9d6-4262-a1c7-b81ae03f8bc0', '2021-04-20 22:42:46.867767-07', 'UCbLOArffWK00tnDMBY-_fkQ', '2021-04-20 21:42:46.867767-07', '', NULL, 'Auto', '2021-11-16 15:29:22.28622-08', 'YouTube', 'c1263a41-7176-4ae1-a0a8-60d6474d2f77', false, 'Queued', true, false, 0, false, '', NULL, false, NULL);
INSERT INTO public.licenses VALUES ('a9336053-ee8d-4a70-9f93-afab1c6b0f52', '2021-04-20 22:42:46.867767-07', 'summit1g', '2021-04-20 22:42:46.867767-07', '', NULL, 'Auto', '2021-11-16 15:29:22.286863-08', 'Twitch', '50f4acd7-a2f7-49a6-aac0-18a53cb0b419', false, 'Queued', true, false, 0, false, '', NULL, false, NULL);
INSERT INTO public.licenses VALUES ('3ed4dfdb-187c-436d-83a0-bef6b45e3412', '2021-04-20 22:42:46.867767-07', 'UCUFgkRb0ZHc4Rpq15VRCICA', '2021-04-20 22:42:46.867767-07', '', NULL, 'Banned', '2021-11-16 15:29:22.287241-08', 'YouTube', '50f4acd7-a2f7-49a6-aac0-18a53cb0b419', false, 'Queued', true, false, 0, false, '', NULL, false, NULL);
INSERT INTO public.licenses VALUES ('63d4ee19-f4f9-4c43-b7d3-02b12ad716cc', '2021-04-20 22:42:46.867767-07', 'xqcow', '2021-04-20 22:42:46.867767-07', '', NULL, 'Auto', '2021-11-16 15:29:22.287566-08', 'Twitch', '50f4acd7-a2f7-49a6-aac0-18a53cb0b419', false, 'Queued', true, true, 0, false, '', NULL, false, NULL);
INSERT INTO public.licenses VALUES ('df68756d-8bdf-4b21-b277-e54e19a11c0c', '2021-04-20 22:42:46.867767-07', 'UCjC8569FjoChhqRsALJSMJA', '2021-04-20 22:42:46.867767-07', '', NULL, 'Auto', '2021-11-16 15:29:22.287926-08', 'YouTube', 'edbe2f96-5549-4cdd-97b7-2f2e3b11415b', false, 'Queued', true, true, 0, false, '', NULL, false, NULL);
INSERT INTO public.licenses VALUES ('b9adb1e7-9402-4324-b73f-49e09d8af3b5', '2021-04-20 22:42:46.867767-07', 'UCqCSl8Eq_0by8ad7u5JZBCD', '2021-04-20 22:42:46.867767-07', '', NULL, 'Auto', '2021-11-16 15:29:22.288278-08', 'YouTube', 'b07a0363-7779-46c3-b260-459e0c23c483', false, 'Queued', true, true, 0, false, '', NULL, false, NULL);


--
-- Data for Name: menu_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.menu_items VALUES ('32e13340-0687-4a68-91f7-6f942ec510b9', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Relaxing Electronic', 'mcat://playlist:b430c9a7-a3af-4cdd-a606-1efae2a0f0c9', 0);
INSERT INTO public.menu_items VALUES ('fb810bf1-c7ac-483d-bc27-6ac0d266c3fd', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Deep House', 'mcat://playlist:ecff3731-79cc-41f9-a355-839b5065231f', 1);
INSERT INTO public.menu_items VALUES ('df439303-0d41-44cb-acc7-f13c907f75fc', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Monstercat: Gaming', 'mcat://playlist:6476fd90-8b48-4dd7-8ae8-1ee7e39e5ad4', 2);
INSERT INTO public.menu_items VALUES ('b8e0335e-5434-4631-84f6-8a0d5933de6a', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Progressive House & Trance', 'mcat://playlist:2207d12c-b579-4522-a0b6-cdf494ab955e', 3);
INSERT INTO public.menu_items VALUES ('e26d69c7-8c56-4d91-921f-9c66e2912d15', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Summertime House | 2020', 'mcat://playlist:986b2a8b-be30-478c-a431-4fb8b6c1c110', 4);
INSERT INTO public.menu_items VALUES ('8a8daf17-0927-4c10-8d58-d7c03c7625e5', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Dance Anthems', 'mcat://playlist:9f2df54d-f5f2-4192-b63f-878990857703', 5);
INSERT INTO public.menu_items VALUES ('1508e8a6-8419-4c27-99e6-df938588fa9c', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Pumped Up EDM', 'mcat://playlist:9a2c6f4e-81dd-431c-a71d-956266f2b1e5', 6);
INSERT INTO public.menu_items VALUES ('ad3f517c-a613-4729-8463-884d3f04594a', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Bass Party', 'mcat://playlist:69bb879e-fde5-4549-9cf7-d90c22207af5', 7);
INSERT INTO public.menu_items VALUES ('ef0f9a29-ed85-4765-b598-cf59aab95417', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Rocket League x Monstercat', 'mcat://playlist:b1425bd9-bd2e-4224-a84e-a68dab27d70e', 8);
INSERT INTO public.menu_items VALUES ('f6a4da6e-d400-4b11-ba9d-24c71b2938a0', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Radio Yonder | Fortnite x Monstercat', 'mcat://playlist:39ab9ef7-b23d-49d7-8f89-f15834954aa6', 9);
INSERT INTO public.menu_items VALUES ('427dac67-9e3c-4212-8c97-ac900a90f46f', 'c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'Roblox x Monstercat', 'mcat://playlist:92b73dcc-f5f0-45c9-ae20-941d2706cba8', 10);
INSERT INTO public.menu_items VALUES ('fbe99da2-014d-440e-b28b-e603bb93f6b5', 'b1729c53-aee1-4aa6-9ddd-9b4aa0eef2bf', 'New Music', '/new', 0);
INSERT INTO public.menu_items VALUES ('e1d50b3d-9281-4b65-9951-307c8cbab331', 'b1729c53-aee1-4aa6-9ddd-9b4aa0eef2bf', 'Explore Catalog', '/browse', 1);
INSERT INTO public.menu_items VALUES ('9f683d98-2cd6-42b0-992a-7ec7443a3fc9', 'b1729c53-aee1-4aa6-9ddd-9b4aa0eef2bf', 'Moods', '/moods', 2);
INSERT INTO public.menu_items VALUES ('a9fa3ec4-dceb-4b07-bf03-30961173320e', 'b1729c53-aee1-4aa6-9ddd-9b4aa0eef2bf', 'Greatest Hits', 'mcat://playlist:9bf60a93-a54f-49c6-b243-c7df9469511d', 3);
INSERT INTO public.menu_items VALUES ('601d47a3-7209-4625-aac2-b3965edd95ba', 'b1729c53-aee1-4aa6-9ddd-9b4aa0eef2bf', 'Best Of Monstercat Silk', 'mcat://playlist:e3536c6e-42f3-4193-a5ac-fe480b2221fa', 4);
INSERT INTO public.menu_items VALUES ('7e895ed3-2ab0-466d-8180-fc0382e8fd93', 'f459c7b8-95b0-4cdb-a159-94d04e22a140', 'Claim-free Sampler', '/free', 0);
INSERT INTO public.menu_items VALUES ('a578af9d-56a2-426a-834f-36b4d4be448d', 'f459c7b8-95b0-4cdb-a159-94d04e22a140', 'New Music', '/new', 1);
INSERT INTO public.menu_items VALUES ('40355b91-38da-49ad-ad99-63ac9e5769c9', 'f459c7b8-95b0-4cdb-a159-94d04e22a140', 'Explore Catalog', '/browse', 2);
INSERT INTO public.menu_items VALUES ('e29ff3e8-a278-427e-899e-8e2ee31806c3', 'f459c7b8-95b0-4cdb-a159-94d04e22a140', 'Moods', '/moods', 3);
INSERT INTO public.menu_items VALUES ('d285ab7c-68ec-48de-8e88-50497ac9325f', 'f459c7b8-95b0-4cdb-a159-94d04e22a140', 'Greatest Hits', 'mcat://playlist:9bf60a93-a54f-49c6-b243-c7df9469511d', 4);
INSERT INTO public.menu_items VALUES ('e1b27d88-8b11-43f0-99a4-f6429e15ba46', 'f459c7b8-95b0-4cdb-a159-94d04e22a140', 'Best Of Monstercat Silk', 'mcat://playlist:e3536c6e-42f3-4193-a5ac-fe480b2221fa', 5);


--
-- Data for Name: menu_sections; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.menu_sections VALUES ('c773492f-d086-4c72-8d0d-bd3ac8fd1692', 'bb64ee58-0ad2-4c12-a82c-84573cb46dfd', 'Official Playlists', 'check', 0);
INSERT INTO public.menu_sections VALUES ('b1729c53-aee1-4aa6-9ddd-9b4aa0eef2bf', 'e913ab4e-b7fd-49d7-99eb-610ca1c7afdd', 'Explore', 'drumstick-bite', 0);
INSERT INTO public.menu_sections VALUES ('f459c7b8-95b0-4cdb-a159-94d04e22a140', '344eb4cf-0632-4c48-84f1-499b21c59bf2', 'Explore', 'car', 0);


--
-- Data for Name: menus; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.menus VALUES ('bb64ee58-0ad2-4c12-a82c-84573cb46dfd', 'Player Official Playlists', 'official_playlists');
INSERT INTO public.menus VALUES ('e913ab4e-b7fd-49d7-99eb-610ca1c7afdd', 'Player Sidebar', 'player_stage');
INSERT INTO public.menus VALUES ('344eb4cf-0632-4c48-84f1-499b21c59bf2', 'Player Sidebar (Free)', 'player_stage_free');


--
-- Data for Name: mood_omitted_songs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: mood_params; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.mood_params VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'danceability', 0.5707616058118368, 0.7469783735782682);
INSERT INTO public.mood_params VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'instrumentalness', 0, 1);
INSERT INTO public.mood_params VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'energy', 0.4185743972862823, 0.6737454311298811);
INSERT INTO public.mood_params VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'liveness', 0.21947233500472993, 0.3419086606606271);
INSERT INTO public.mood_params VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'loudness', -17.63222074857901, -10.470109010867944);
INSERT INTO public.mood_params VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'speechiness', 0.050121155592834796, 0.1542492456366352);
INSERT INTO public.mood_params VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'valence', 0.05584247922161504, 0.42772851509233073);
INSERT INTO public.mood_params VALUES ('37876ed5-c4f0-483e-a64d-3ba85170475e', 'danceability', 0, 1);
INSERT INTO public.mood_params VALUES ('37876ed5-c4f0-483e-a64d-3ba85170475e', 'acousticness', NULL, 0.2023083641183892);
INSERT INTO public.mood_params VALUES ('37876ed5-c4f0-483e-a64d-3ba85170475e', 'energy', 0.5387221934906674, 0.7343914615949516);
INSERT INTO public.mood_params VALUES ('37876ed5-c4f0-483e-a64d-3ba85170475e', 'loudness', -16.649185804187297, -7.3103538324660065);
INSERT INTO public.mood_params VALUES ('37876ed5-c4f0-483e-a64d-3ba85170475e', 'speechiness', 0.05927527339888318, 0.2824068949213126);
INSERT INTO public.mood_params VALUES ('33d278fd-a812-46e7-8d2f-205ea4ad4f83', 'acousticness', NULL, 0.31215777779096987);
INSERT INTO public.mood_params VALUES ('33d278fd-a812-46e7-8d2f-205ea4ad4f83', 'energy', 0.8041916098660706, NULL);
INSERT INTO public.mood_params VALUES ('33d278fd-a812-46e7-8d2f-205ea4ad4f83', 'liveness', 0.26524292403497185, 0.5158368989755464);
INSERT INTO public.mood_params VALUES ('33d278fd-a812-46e7-8d2f-205ea4ad4f83', 'loudness', -9.346640502991704, NULL);
INSERT INTO public.mood_params VALUES ('33d278fd-a812-46e7-8d2f-205ea4ad4f83', 'speechiness', 0.13594101002453843, 0.2778298360182884);
INSERT INTO public.mood_params VALUES ('b92413a1-d788-4167-86ff-af513b5e20b6', 'acousticness', NULL, 0.12907542167000213);
INSERT INTO public.mood_params VALUES ('b92413a1-d788-4167-86ff-af513b5e20b6', 'energy', 0.8568277872508488, NULL);
INSERT INTO public.mood_params VALUES ('b92413a1-d788-4167-86ff-af513b5e20b6', 'loudness', -7.591220959435063, -1.482360947857977);
INSERT INTO public.mood_params VALUES ('da29ace3-54fc-4442-a361-0539e0222cbc', 'acousticness', NULL, 0.06842939120493156);
INSERT INTO public.mood_params VALUES ('da29ace3-54fc-4442-a361-0539e0222cbc', 'danceability', 0.5204139578785706, 0.646283077711736);
INSERT INTO public.mood_params VALUES ('da29ace3-54fc-4442-a361-0539e0222cbc', 'energy', 0.7126504318055867, 0.8465294047190444);
INSERT INTO public.mood_params VALUES ('da29ace3-54fc-4442-a361-0539e0222cbc', 'loudness', -14.402248788434797, -4.712332908002189);
INSERT INTO public.mood_params VALUES ('da29ace3-54fc-4442-a361-0539e0222cbc', 'speechiness', 0.06499659702766343, 0.20459689356990132);
INSERT INTO public.mood_params VALUES ('3ef2b38b-5cbe-47be-818a-a355bdf600bb', 'danceability', 0.6302633715511513, 0.7721521975449013);
INSERT INTO public.mood_params VALUES ('3ef2b38b-5cbe-47be-818a-a355bdf600bb', 'energy', 0.7023520492737823, 0.838519551638752);
INSERT INTO public.mood_params VALUES ('3ef2b38b-5cbe-47be-818a-a355bdf600bb', 'instrumentalness', NULL, 0.31902336614550614);
INSERT INTO public.mood_params VALUES ('3ef2b38b-5cbe-47be-818a-a355bdf600bb', 'liveness', NULL, 0.3133020425167259);
INSERT INTO public.mood_params VALUES ('3ef2b38b-5cbe-47be-818a-a355bdf600bb', 'loudness', -19.879157764331502, -8.784906249053577);
INSERT INTO public.mood_params VALUES ('3ef2b38b-5cbe-47be-818a-a355bdf600bb', 'speechiness', NULL, 0.14852792200785495);


--
-- Data for Name: moods; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.moods VALUES ('f1e57895-6a7f-40bd-9172-ab0a0678dd14', 'Chill', 'chill', '', '{}', NULL, 'UTC', 'e77fce2c-05c4-47b6-8fe5-c7d4bcadbbdb', '1c918c64-0d46-46f5-ada3-1422833e46a9');
INSERT INTO public.moods VALUES ('37876ed5-c4f0-483e-a64d-3ba85170475e', 'Good Vibes', 'good-vibes', '', '{}', NULL, 'UTC', '67d5beb5-3428-4338-ba36-051e5ff114c2', '835588fe-d7d6-4d60-a88f-b575df315d1a');
INSERT INTO public.moods VALUES ('33d278fd-a812-46e7-8d2f-205ea4ad4f83', '1337', '1337', '', '{}', NULL, '', 'a39152fd-3222-4a9c-b71a-71670f68691f', 'cbcd158b-7165-4487-adaa-fe4bfbffb7b9');
INSERT INTO public.moods VALUES ('b92413a1-d788-4167-86ff-af513b5e20b6', 'Amped', 'amped', '', '{}', NULL, '', '4e590458-e206-4b4e-b176-14f1a257c8cf', '612cee8a-efeb-42fb-b28a-1410899aa880');
INSERT INTO public.moods VALUES ('da29ace3-54fc-4442-a361-0539e0222cbc', 'Footwork', 'footwork', '', '{}', NULL, '', '6c2508c2-3704-442e-ad15-cbabf937fa07', '1bb4cb32-a472-4040-8e5e-857ff844e226');
INSERT INTO public.moods VALUES ('3ef2b38b-5cbe-47be-818a-a355bdf600bb', 'Popped', 'popped', '', '{}', NULL, '', '48990de4-fb2a-46f6-be92-46c976f50aff', 'f657e640-d0ad-4f94-877c-6932b155d0f8');


--
-- Data for Name: page_counter; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: paypal_payments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: paypal_subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.paypal_subscriptions VALUES ('59b1e5f6-a0a3-4050-aefe-4cb858d26eff', 'I-XM01J0A1JW4A', 'XSJXT7658FA33', 'Active', '99315a02-c984-4dc4-92c4-68ed29907850');
INSERT INTO public.paypal_subscriptions VALUES ('e59853b3-ce45-4697-bd23-60d46fe7d465', 'I-ABCDJ0A1J333', 'ABCDE7658FA33', 'Active', '9f0c3fa4-f3d4-4203-816c-09c77035f238');
INSERT INTO public.paypal_subscriptions VALUES ('91bb8f4a-d776-4758-b62e-0e906dd7a8d5', 'I-P46JUWLDN2EH', '', 'Active', 'b07a0363-7779-46c3-b260-459e0c23c483');


--
-- Data for Name: playlist_items; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.playlist_items VALUES ('ecccd368-0fe5-4b44-abdc-e5796efe3418', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 0);
INSERT INTO public.playlist_items VALUES ('2643a351-f908-4f24-a922-6798d70d804d', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 0);
INSERT INTO public.playlist_items VALUES ('2643a351-f908-4f24-a922-6798d70d804d', '786e3696-e0ad-4d43-8ec2-44575e35f85c', '2d1f8eb0-c983-4ec7-bbf3-34df9db10e29', 1);
INSERT INTO public.playlist_items VALUES ('06635238-1390-434e-aff5-2c5964cd8b2f', 'f25fbe4e-3449-4804-bfff-2a01cf6a77fc', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 0);
INSERT INTO public.playlist_items VALUES ('06635238-1390-434e-aff5-2c5964cd8b2f', 'f25fbe4e-3449-4804-bfff-2a01cf6a77fc', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 1);
INSERT INTO public.playlist_items VALUES ('06635238-1390-434e-aff5-2c5964cd8b2f', 'f25fbe4e-3449-4804-bfff-2a01cf6a77fc', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 2);
INSERT INTO public.playlist_items VALUES ('5328ddfd-b47b-40a4-a8c9-3de8f11ec283', 'f25fbe4e-3449-4804-bfff-2a01cf6a77fc', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 0);
INSERT INTO public.playlist_items VALUES ('5328ddfd-b47b-40a4-a8c9-3de8f11ec283', 'f25fbe4e-3449-4804-bfff-2a01cf6a77fc', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 1);
INSERT INTO public.playlist_items VALUES ('5328ddfd-b47b-40a4-a8c9-3de8f11ec283', 'f25fbe4e-3449-4804-bfff-2a01cf6a77fc', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 2);
INSERT INTO public.playlist_items VALUES ('8dc0a933-f7dc-47d8-a32c-2e9474a0c5be', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 0);
INSERT INTO public.playlist_items VALUES ('8dc0a933-f7dc-47d8-a32c-2e9474a0c5be', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 1);
INSERT INTO public.playlist_items VALUES ('8dc0a933-f7dc-47d8-a32c-2e9474a0c5be', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 2);
INSERT INTO public.playlist_items VALUES ('8dc0a933-f7dc-47d8-a32c-2e9474a0c5be', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 3);
INSERT INTO public.playlist_items VALUES ('8dc0a933-f7dc-47d8-a32c-2e9474a0c5be', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 4);
INSERT INTO public.playlist_items VALUES ('8dc0a933-f7dc-47d8-a32c-2e9474a0c5be', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 5);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 0);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '786e3696-e0ad-4d43-8ec2-44575e35f85c', '2d1f8eb0-c983-4ec7-bbf3-34df9db10e29', 1);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '9bd7e2ff-9fa9-46b8-9c0f-d9c1ea789da2', 'dd10070c-8145-4862-900d-507a127d5d0b', 2);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '85656610-6349-45de-96dc-cb40f7c39f8e', '2bd33e53-4a6d-4e0f-bbef-862ed971381a', 3);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '884b21ac-2cfc-4cec-9b27-89893a9f913e', '52128b8c-88e2-4434-af29-117a37111dce', 4);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '86661dce-4e7f-40d1-970d-3b890202c1a5', '52128b8c-88e2-4434-af29-117a37111dce', 5);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '94c41136-e480-42c3-ab9a-77bc09cfb5e0', '158e62d5-3f54-4f65-9181-1d5ff4185121', 6);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '30ad5d48-5731-4055-958e-41ba0031dd19', 'de444ab3-33a9-4640-ab05-f1d40871bb7a', 7);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '12d09d13-04ba-4e4e-ad4c-8595819ba207', '2302c9d2-7691-4c8a-8efd-0484877d2e05', 8);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '24b1e4f9-11c7-4e53-b4bf-8bfbd5e29289', '6caf3747-0198-4c15-acfa-ffa66dcd576b', 9);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '9e6ccccc-773f-4542-a1e8-00e372cdb7ae', 'f54d7f22-4661-4c77-88a7-5d04237d462d', 10);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'a1cdc3f5-1bc8-4ff5-8e9a-924e9983fa64', '49348eeb-7372-4857-a40f-984b17b1473f', 11);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'a64317d6-437f-4f22-acfc-5df9c682d5fe', '6ccde9a9-e04a-4791-ac0b-9ceb6bab1560', 12);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'e73463bc-c65b-469e-9ba4-e964bb1679ef', '313bcb4c-39db-43ed-8804-24d2efa7c7d8', 13);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '3cff80d6-9dde-41fc-99fd-55cf9cdf5a16', 'dd1a38c9-bbf6-44c5-a883-7d6b59825945', 14);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'fa590713-57bc-431d-a38e-66cf171beae8', '9f2206a8-1007-41c4-8de2-f9ac32e64731', 15);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '7633e62b-2000-4a6b-83fd-6f2af9ebdbe8', '0fdb684f-5629-4336-98ec-5c122bf3c2a1', 16);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'cd44d732-0988-4971-8e37-4d5be7bf6443', '898ccf37-11b1-4dec-86c5-34d8d44dfa33', 17);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '37b350fb-cdfc-422d-8e7a-876f67ed4530', 'afac16a7-df93-4114-9b0f-6e5c65d60104', 18);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'be077a77-d2b4-4aaf-875d-bf47118e6427', 'afac16a7-df93-4114-9b0f-6e5c65d60104', 19);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '80886d27-212a-41fa-a632-68455e521ff2', 'edb37970-a43e-40ce-a4ed-fbee53cd361f', 20);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '19c5e559-e849-4692-91df-3069a88b3f3f', '80d29f81-7e01-4e63-8445-24bf365eb7ea', 21);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '9463351e-e0c6-4865-a434-0b392ee47d5a', '7cf74d4e-4799-4b40-a0f3-8aebe89746b5', 22);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'e2197257-d082-4bc7-993e-b80ba0b47ee8', 'f8931bb8-fcaa-42b0-88d2-b131ddebc710', 23);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'a0eb2d2e-e76c-4288-9d01-e12824261683', '8610cd87-141f-4403-9632-1e8ae868ee79', 24);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'da3c2d7b-a128-4436-815e-f72a370b21e7', '9eac0a60-421e-4d2d-9167-ad5cc06eed34', 25);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '55cc53c8-2182-4a5e-91e4-911c21de34f8', '29869446-6422-44ce-983d-6ab9ec7cb2b1', 26);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '1bbacbce-7e8d-4ad0-a207-637a7fe9ef13', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 27);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '94f8c643-9074-45d5-a000-e4fa6431b9d1', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 28);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'b7f27ada-f84f-490a-8003-3926bf58e5ed', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 29);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '7246efbd-94a1-4f47-b32a-dae896a08fd4', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 30);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '4f278ed6-0fbf-489a-9357-510f8e66af7f', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 31);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '81408fe7-38f8-4985-9dfc-203ece2506c5', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 32);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '5fb6f31d-f7bf-4da7-973e-b7e89d1ca00b', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 33);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'a1a372e1-bf92-49c9-abe9-e9f7fc05c85b', 'ad6b16ba-0b78-4de2-9495-dcf4fbf5ab72', 34);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'b3b9351f-471e-4cf8-b7b8-9ac72efcd2ac', '0fb14ce0-e696-4ee1-bd01-658b84ecc715', 35);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '58d9ace7-a084-4fc0-b2da-53387015e6e6', 'dc20cdd1-a0b6-4d1d-8039-20f925e6c580', 36);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '4fd34717-a0d1-4517-ae28-18ccbf6d8956', '235798e8-342a-495c-abf2-b1e70797ac10', 37);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'c8bef866-5e7f-4b65-bc70-b18746f2e92d', 'aae6e648-41b1-44e3-abdb-a5d96daf0818', 38);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '282ff8d4-988a-4791-beab-1276f988c222', 'b2046995-fd25-448a-aa3b-5649a9875627', 39);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '253d1f14-d858-423d-bd31-f072fb2dad49', 'ce7aadee-522b-42e0-91b8-c3ab2f088e95', 40);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '2c9b08cc-0e6e-43cf-acf1-df8ab2548ca4', '33e8eee8-51e4-4548-ab74-36e79c038244', 41);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '562f384a-f931-4424-9fc2-fc99296e2c5d', '81a1b68b-3375-4ad6-a09e-06ecf75d1c40', 42);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'ab1f63dd-3eab-4849-82fc-57590ad4dea7', 'c121522d-d32b-49bd-8e18-f0a833b946cc', 43);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '45aa7cf8-a227-495c-866c-b088f3c80a49', 'cd6c2790-f0d3-44a8-98e1-0319da6d2a7e', 44);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'f6148a5e-b7b2-4499-9245-20ce66867a78', '36cb5134-d4fb-4bc8-a76a-eba8188cf830', 45);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'e07cbff2-28fd-42b4-babd-5d75d069a6c3', '36cb5134-d4fb-4bc8-a76a-eba8188cf830', 46);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'a62eeee0-6a44-434b-bbdb-e17244fdc6ee', '36cb5134-d4fb-4bc8-a76a-eba8188cf830', 47);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '7d3714df-a45b-49de-9bbb-c0333c8190a9', 'ccfeface-0277-41ac-9b4f-35b0c8823c75', 48);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '5509e30f-ba0d-4c2a-8b43-da983ba24045', 'ccfeface-0277-41ac-9b4f-35b0c8823c75', 49);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '89422d06-45ec-4ef8-9202-5f6c0f43a4e1', 'ccfeface-0277-41ac-9b4f-35b0c8823c75', 50);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'd9085bc5-c09b-487d-a7b9-1eba0e234e84', 'c0ceb431-9b24-4996-90a1-aee9d4ee7f59', 51);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'a83655cb-ede8-414f-8653-71158e0bc197', '6d865bf7-072d-4f36-847c-160299610724', 52);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'fcf7d843-cb73-49d2-8df1-0a771d04fca9', 'f5c67e01-5a3e-46d4-8b1d-859a8cc4d0df', 53);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '3bbd2a51-2c4e-4d97-9052-5b2b8b7ffd46', 'e9df46e6-0db8-49ed-a4a3-5f3e39889a19', 54);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '512ae09f-f8c6-42e1-9b56-ba5f692b8ed3', 'b088bd74-96ae-4ae3-87bc-b3973a051b0e', 55);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '7371e380-fdfe-4adc-9f78-469ff0dbabdd', 'd6faf586-4889-435d-af19-8afc0e897b78', 56);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'b64c9566-6925-4c28-a864-d98d50e5bef7', 'abadd406-eaca-4a9e-8f51-0fbf1b9d0bbd', 57);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '0248f8cd-725f-486f-a5e2-00fec56e15a0', '292d9de4-91e1-4ddd-a2cf-130876f43910', 58);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '48c81539-36a2-4134-b2af-e227c9222c06', '9a1b4384-4d54-45a1-acb2-8454945b1d16', 59);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '0a71d640-a7b5-462b-9df0-e00377df4e27', 'a9065505-77d4-4c92-a1a9-3fcb61e08907', 60);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'c349bb06-c03b-4c5e-ae8f-630362ce6bf4', 'cd1cfc65-1cd9-438e-a65e-c5c402f7b0b9', 61);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '549ef90c-8821-4591-8103-0b7477a9d425', '23122b7d-e55c-4a07-8f68-4490cf4c8877', 62);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '83ab4552-81cc-43b0-a106-d0b3ec5da4db', '87cfb8b2-be8f-40ea-80fd-69f0785a3c60', 63);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '21fc59af-9706-417b-abcd-b45b00f83c98', 'fa6ab24e-6161-4fe6-8ef1-54b22cd26dde', 64);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '50013bce-b14d-479a-a3fb-af7bf5230975', '2100a543-64da-4f28-839a-ca9d14ea99bf', 65);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '955ee9fc-0ce7-468d-976d-66036e801ca9', 'b5656c9a-a942-41e3-90e2-517cd80dc678', 66);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'ac2378d1-d07c-4c3b-9f16-9bd4c5379417', '09f029d2-57fa-4672-bb78-dd82ad680e4b', 67);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'f2bf0fb5-c7ce-46ea-90d6-8610b470b01a', 'f954bf62-965f-457f-98cf-9b86463bdd91', 68);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '06fa0008-5e09-478c-86cf-a7fb5e42f86d', '48772565-446f-4572-a9fb-42f17b393103', 69);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'f6e50a12-3a0d-4a03-9922-272e48c1266f', '5401b822-7726-42d0-9a70-a7314a62bd6f', 70);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '65e3a254-d2fd-4278-a0a1-a5f837c342b6', '28a442fc-7ac5-459d-944e-2df91935a122', 71);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '7a4e89c6-1a00-4d5e-a3d9-9b193810b25e', 'b4697497-e85d-475e-96f2-346811d3ff85', 72);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '92d433d8-02fb-4c75-9189-24c0b2dd0956', 'dbd66e0c-c5da-49ef-b3a8-afda151e9647', 73);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '1b7bb939-0d69-4f58-a58e-eaf998d593f3', 'ad6eefcc-f89d-4a7a-8714-b1356a4ab929', 74);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '40004ac8-064c-43cb-b773-32e8b4e11bf5', 'c368b73f-33ca-4fb8-9c22-a34b08e7043f', 75);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'acf57996-c449-4fe4-9028-002a56f68a35', 'c368b73f-33ca-4fb8-9c22-a34b08e7043f', 76);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '50521c06-7ec1-4d43-a722-dc4257f4ef98', '3302b8b3-1c7e-496c-91b3-9bb462935b69', 77);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'f134f831-6b13-4aff-acaa-d4fa5b0a6579', '3d6f307b-71e7-4f95-8914-901c9817f1f2', 78);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'd7caee97-3b98-4877-9f35-82eb8c8e9eea', 'eefc8e44-edc8-424f-83a8-e0c7335d0b34', 79);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '616df27b-5eff-4be0-9c3e-e910f54c0183', '8c9c26b5-798d-425f-949b-40c6b2103ebf', 80);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '60afc5ae-0f08-4e57-8abc-97fa354ec1e5', '051bc2a6-f790-4502-b6d8-84917d7eb278', 81);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'a92da736-c450-4e68-b218-9bd852b855e1', 'bebd4a09-f730-4746-8c50-cf8cae77ffcb', 82);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '10c224b2-2180-4cbd-a692-84e758e88bb4', '11173738-37c3-409a-8e03-d860db623dac', 83);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'ea29e729-d96c-4b64-86eb-f6bfc21ca251', '6c1297a1-66dd-4557-9771-80fab93b0709', 84);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '5b1328e0-3be9-42f3-9697-839cfbe5857a', 'e049ea6a-75f4-4917-b70c-1fa1bc1fd5d5', 85);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '9413b64e-d700-4cc5-92c3-438a8b045ced', 'bb8e6eea-506a-433c-9433-19a40792f7d0', 86);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '630d4ef4-a68e-4d81-8eb8-8c48be701e1e', 'bb8e6eea-506a-433c-9433-19a40792f7d0', 87);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'babfab1f-a63b-448e-a7ae-581d23739b86', '4b70a7b5-7baf-45a7-b873-54965bfb1894', 88);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'b30b499d-c802-4607-b396-8128c6857304', 'c8e181b3-39cc-43f6-8056-afd628394ad7', 89);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'f8c2ad15-4ac8-4437-80ad-1bf6f02f0daf', '8d7d2f88-dc31-4c79-aa8c-7229be4ef156', 90);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '552aa601-1353-4d4d-8433-c8db90f6c683', '7c15e1df-9a18-40aa-ac81-15995f794833', 91);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '01ed2eb4-2bb2-44c9-9cc0-388350bd4bc2', '426fbc3a-8356-4db6-a3e2-c5f53dda24b8', 92);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '9bd2ff7c-5eb6-4b4f-8375-6b2021f58c05', '60f189ae-68f5-4647-a09e-40e97af37ae9', 93);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'bfab981c-6fd1-4546-a39f-2d76d96282a5', '822d9fd6-8aa4-41bf-a463-255453f99ff5', 94);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'd51c3b36-71ec-4b29-a6ba-bdbd57de48d9', '1558b59d-329d-43b8-90d2-79c027639165', 95);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', 'c48c4c7e-03ec-4d5f-be1d-1e5abb6bdf66', 'f3473f25-c96d-418b-bb71-89134cada1c9', 96);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '2462ef19-07d5-4022-9e1e-ad2229aab7dd', '2070510c-0ba3-4f8c-853e-1b800cbbb0cd', 97);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '238bec4e-3859-4e31-acb9-c742f000f14b', '6b2e57b0-ba98-42a6-8314-4d883befedce', 98);
INSERT INTO public.playlist_items VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '61a4b0a6-be5e-4f72-9d4c-e9c8cb93c698', '338afd86-180d-4c32-b266-a862b80a035e', 99);
INSERT INTO public.playlist_items VALUES ('ee0e6db1-88c0-40bd-8c4f-aedb07eb0854', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 0);
INSERT INTO public.playlist_items VALUES ('ee0e6db1-88c0-40bd-8c4f-aedb07eb0854', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 1);
INSERT INTO public.playlist_items VALUES ('ee0e6db1-88c0-40bd-8c4f-aedb07eb0854', '0d4463ae-ddbb-43c9-bc33-a500861b2e46', '0eac85f3-2c8c-4e69-a369-7c5481b473fd', 2);
INSERT INTO public.playlist_items VALUES ('9bf60a93-a54f-49c6-b243-c7df9469511d', '005d4086-a406-4483-b689-0fb9f4b840e6', 'fb54934d-d10e-42bf-8a99-ab6489cb9e93', 2);
INSERT INTO public.playlist_items VALUES ('6476fd90-8b48-4dd7-8ae8-1ee7e39e5ad4', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', '520ef14d-8ff0-4968-866a-b8de41308c9d', 0);
INSERT INTO public.playlist_items VALUES ('6476fd90-8b48-4dd7-8ae8-1ee7e39e5ad4', '007f63b4-5d53-4c0d-b17e-2465556057ea', 'c615e91a-ba34-4c3f-ae8a-e1ab8d992632', 1);
INSERT INTO public.playlist_items VALUES ('6476fd90-8b48-4dd7-8ae8-1ee7e39e5ad4', '0076de74-abf3-40c1-8b02-e58f2987a985', 'd8d7dc78-d8d2-473d-ad80-b9bbe22e9dd8', 3);
INSERT INTO public.playlist_items VALUES ('926b2986-16ae-4701-92c8-23071225e016', '00bbfb60-f9cd-47e6-88a9-34318bcc1886', 'ecec307f-bdab-4431-a0af-9f46156a2475', 2);
INSERT INTO public.playlist_items VALUES ('926b2986-16ae-4701-92c8-23071225e016', '005a2330-8bc4-4a8d-b234-f42b0f898e64', '7067aedd-108a-4993-95cc-29506b01096f', 3);
INSERT INTO public.playlist_items VALUES ('926b2986-16ae-4701-92c8-23071225e016', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', '520ef14d-8ff0-4968-866a-b8de41308c9d', 4);
INSERT INTO public.playlist_items VALUES ('2207d12c-b579-4522-a0b6-cdf494ab955e', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'f6306e1d-171d-4fc0-b749-687a6a47beae', 0);
INSERT INTO public.playlist_items VALUES ('2207d12c-b579-4522-a0b6-cdf494ab955e', '00d20487-e462-4630-863c-7b9f58d6dc50', '0cf81f33-5882-4ef1-9c27-c49ab1d18a49', 2);
INSERT INTO public.playlist_items VALUES ('2207d12c-b579-4522-a0b6-cdf494ab955e', '009250a8-e860-413e-b16b-1f83c72a79ad', '8d445cdf-0f39-45e7-8bc1-787b404be2d1', 3);
INSERT INTO public.playlist_items VALUES ('b430c9a7-a3af-4cdd-a606-1efae2a0f0c9', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'f6306e1d-171d-4fc0-b749-687a6a47beae', 1);
INSERT INTO public.playlist_items VALUES ('9bf60a93-a54f-49c6-b243-c7df9469511d', '00749cf3-60cb-4e8a-a3ef-3153deefbb53', '3b10d404-d8aa-4743-9d47-4ef719918040', 3);
INSERT INTO public.playlist_items VALUES ('6476fd90-8b48-4dd7-8ae8-1ee7e39e5ad4', '007f63b4-5d53-4c0d-b17e-2465556057ea', '825e6dd7-1c56-4716-918b-74afb6fc67c4', 2);
INSERT INTO public.playlist_items VALUES ('926b2986-16ae-4701-92c8-23071225e016', '007f63b4-5d53-4c0d-b17e-2465556057ea', '825e6dd7-1c56-4716-918b-74afb6fc67c4', 0);
INSERT INTO public.playlist_items VALUES ('2207d12c-b579-4522-a0b6-cdf494ab955e', '0003b274-e31f-448a-8c7c-66085e76a0e3', 'f149d857-bf82-4230-af3c-377f0f740c6f', 1);
INSERT INTO public.playlist_items VALUES ('926b2986-16ae-4701-92c8-23071225e016', '00a29fc8-e728-4274-9cc8-558374195c04', 'aebba702-628c-4f55-8ffb-02e31f11bd39', 1);
INSERT INTO public.playlist_items VALUES ('926b2986-16ae-4701-92c8-23071225e016', '00749cf3-60cb-4e8a-a3ef-3153deefbb53', '3b10d404-d8aa-4743-9d47-4ef719918040', 5);
INSERT INTO public.playlist_items VALUES ('9a2c6f4e-81dd-431c-a71d-956266f2b1e5', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'aa22609b-f146-4aa7-a34c-2ed655e4c74e', 0);
INSERT INTO public.playlist_items VALUES ('9a2c6f4e-81dd-431c-a71d-956266f2b1e5', '0003b274-e31f-448a-8c7c-66085e76a0e3', '2184c7a0-8453-498b-b5e4-7f066b2718b9', 1);
INSERT INTO public.playlist_items VALUES ('9a2c6f4e-81dd-431c-a71d-956266f2b1e5', '003f7cfd-9b21-4b15-a3b2-6ab209f2f82d', '41ae27e9-ea9e-4d81-a8bb-f4546872f00f', 2);
INSERT INTO public.playlist_items VALUES ('9a2c6f4e-81dd-431c-a71d-956266f2b1e5', '0044914e-0a18-490e-9e24-60643f3a66ed', 'a6ee5b60-59fc-4fed-9799-fbdc807e6cc6', 3);
INSERT INTO public.playlist_items VALUES ('b430c9a7-a3af-4cdd-a606-1efae2a0f0c9', '00bbfb60-f9cd-47e6-88a9-34318bcc1886', '70beba27-a0d4-4bc3-9611-c4a33879d9d3', 0);
INSERT INTO public.playlist_items VALUES ('b430c9a7-a3af-4cdd-a606-1efae2a0f0c9', '0124bed4-c0e8-4328-90d7-672b14dde366', 'a4477623-1a58-46b7-b2af-41dd2335383c', 2);
INSERT INTO public.playlist_items VALUES ('92b73dcc-f5f0-45c9-ae20-941d2706cba8', '005a2330-8bc4-4a8d-b234-f42b0f898e64', '7067aedd-108a-4993-95cc-29506b01096f', 0);
INSERT INTO public.playlist_items VALUES ('92b73dcc-f5f0-45c9-ae20-941d2706cba8', '0003b274-e31f-448a-8c7c-66085e76a0e3', 'f149d857-bf82-4230-af3c-377f0f740c6f', 1);
INSERT INTO public.playlist_items VALUES ('b1425bd9-bd2e-4224-a84e-a68dab27d70e', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'f6306e1d-171d-4fc0-b749-687a6a47beae', 1);
INSERT INTO public.playlist_items VALUES ('986b2a8b-be30-478c-a431-4fb8b6c1c110', '00e19ded-d904-41eb-abec-fea60fc5b747', '64661631-8bd2-4055-a273-ffdb01baf54c', 0);
INSERT INTO public.playlist_items VALUES ('575847d5-35f3-4100-a7a4-a59bccde82eb', '0fec3c9e-0bc6-4163-9266-8c4d2b9ebae0', '85b4cee0-551f-46d5-922d-f0e69bed3a17', 3);
INSERT INTO public.playlist_items VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '0076de74-abf3-40c1-8b02-e58f2987a985', 'd8d7dc78-d8d2-473d-ad80-b9bbe22e9dd8', 2);
INSERT INTO public.playlist_items VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '005d4086-a406-4483-b689-0fb9f4b840e6', 'fb54934d-d10e-42bf-8a99-ab6489cb9e93', 3);
INSERT INTO public.playlist_items VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '009250a8-e860-413e-b16b-1f83c72a79ad', '8d445cdf-0f39-45e7-8bc1-787b404be2d1', 5);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '2e7b65ae-7ff6-4492-9509-6713f88087d2', 'e93a9d7e-e134-4b10-a231-ef72fca4ca3b', 0);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '4609fd61-e99b-494e-829a-d5eb7ea57df8', 'f0e72bb4-084a-4491-8e52-e178c5b93b6f', 1);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '234722a2-98f5-479e-a858-38abfe03ec20', 'f0e72bb4-084a-4491-8e52-e178c5b93b6f', 2);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '0fa0ea68-07cd-4e71-8e5d-56842b99fe15', 'f0e72bb4-084a-4491-8e52-e178c5b93b6f', 3);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '4d1ad2e8-2328-456a-8c8d-c1f6d785012d', 'f0e72bb4-084a-4491-8e52-e178c5b93b6f', 4);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '481f6178-a58f-4868-aad4-d48db949a81a', 'efbe7bc5-5d13-49da-af7d-54a24ed585d3', 5);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', 'c3b1f20e-ec9e-40fc-9fd9-cfc2813f56a9', '1d2b93fc-b39a-40c5-b7bc-6b283c83a93f', 6);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', 'abbf5762-d991-4b05-845c-c4b188d684d1', '33f84101-247d-4795-93ac-99765c17afd9', 7);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '9f55cb5d-c446-4127-8dae-9a5cf3aa8344', 'dd4aa863-bea1-4c9e-aad5-9309e6f55be5', 8);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '3a0a5f7b-c1d8-4608-8424-7b2258c7ad1b', 'dd4aa863-bea1-4c9e-aad5-9309e6f55be5', 9);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '2866cb43-3471-43fc-bf45-843592fa7d89', 'dd4aa863-bea1-4c9e-aad5-9309e6f55be5', 10);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', 'f608524a-1955-44a7-a4f4-9334b674edb2', 'dd4aa863-bea1-4c9e-aad5-9309e6f55be5', 11);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '26e4143a-eb11-4174-95b1-bc8d1f056c3b', 'dd4aa863-bea1-4c9e-aad5-9309e6f55be5', 12);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', 'd39d744f-3926-45ca-bae5-afc270542d0f', 'dd4aa863-bea1-4c9e-aad5-9309e6f55be5', 13);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '7089b408-b359-40ec-baca-247f930b4c9f', 'dd4aa863-bea1-4c9e-aad5-9309e6f55be5', 14);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '3cceca75-c26d-4dc3-a95a-042b1d37873c', '567f7598-2b39-424f-bc28-119e806febf7', 15);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '4873e1a0-c8aa-4950-818f-7e1533f4574c', '567f7598-2b39-424f-bc28-119e806febf7', 16);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '3486ec38-ad96-45af-9451-0868bee629f9', '567f7598-2b39-424f-bc28-119e806febf7', 17);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', 'd02b1100-3b48-4765-acdf-6c713346bd3f', '567f7598-2b39-424f-bc28-119e806febf7', 18);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '3cbd0735-936b-4369-b36d-93ac972cea62', '567f7598-2b39-424f-bc28-119e806febf7', 19);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', 'c2fba19f-bb64-41ba-8bcc-61ba570d1590', '09999148-a034-4773-9378-d33c53c73f3c', 20);
INSERT INTO public.playlist_items VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', 'a9d0db5b-37d7-4fd5-9ebf-87bdaca1df3f', '09999148-a034-4773-9378-d33c53c73f3c', 21);
INSERT INTO public.playlist_items VALUES ('9bf60a93-a54f-49c6-b243-c7df9469511d', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'aa22609b-f146-4aa7-a34c-2ed655e4c74e', 0);
INSERT INTO public.playlist_items VALUES ('9bf60a93-a54f-49c6-b243-c7df9469511d', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'f6306e1d-171d-4fc0-b749-687a6a47beae', 1);
INSERT INTO public.playlist_items VALUES ('92b73dcc-f5f0-45c9-ae20-941d2706cba8', '0044914e-0a18-490e-9e24-60643f3a66ed', 'a6ee5b60-59fc-4fed-9799-fbdc807e6cc6', 2);
INSERT INTO public.playlist_items VALUES ('69bb879e-fde5-4549-9cf7-d90c22207af5', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', '520ef14d-8ff0-4968-866a-b8de41308c9d', 0);
INSERT INTO public.playlist_items VALUES ('69bb879e-fde5-4549-9cf7-d90c22207af5', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'f6306e1d-171d-4fc0-b749-687a6a47beae', 1);
INSERT INTO public.playlist_items VALUES ('69bb879e-fde5-4549-9cf7-d90c22207af5', '007f63b4-5d53-4c0d-b17e-2465556057ea', 'c615e91a-ba34-4c3f-ae8a-e1ab8d992632', 2);
INSERT INTO public.playlist_items VALUES ('69bb879e-fde5-4549-9cf7-d90c22207af5', '009250a8-e860-413e-b16b-1f83c72a79ad', 'bc1e3f2c-07ec-47bb-ab79-09a679125fdd', 3);
INSERT INTO public.playlist_items VALUES ('e3536c6e-42f3-4193-a5ac-fe480b2221fa', '002e08d3-05ce-42b3-b634-dbb260369082', '0a540642-38d2-4e4d-a986-3ceed0f9562c', 0);
INSERT INTO public.playlist_items VALUES ('e3536c6e-42f3-4193-a5ac-fe480b2221fa', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'aa22609b-f146-4aa7-a34c-2ed655e4c74e', 1);
INSERT INTO public.playlist_items VALUES ('e3536c6e-42f3-4193-a5ac-fe480b2221fa', '009250a8-e860-413e-b16b-1f83c72a79ad', '8d445cdf-0f39-45e7-8bc1-787b404be2d1', 2);
INSERT INTO public.playlist_items VALUES ('e3536c6e-42f3-4193-a5ac-fe480b2221fa', '00c33bce-4a9b-468a-89bf-1516694dea4a', 'fcf0bdcf-36bc-458d-9bc6-4bd8105cbb25', 3);
INSERT INTO public.playlist_items VALUES ('b1425bd9-bd2e-4224-a84e-a68dab27d70e', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'aa22609b-f146-4aa7-a34c-2ed655e4c74e', 0);
INSERT INTO public.playlist_items VALUES ('b1425bd9-bd2e-4224-a84e-a68dab27d70e', '00749cf3-60cb-4e8a-a3ef-3153deefbb53', '3b10d404-d8aa-4743-9d47-4ef719918040', 2);
INSERT INTO public.playlist_items VALUES ('b1425bd9-bd2e-4224-a84e-a68dab27d70e', '009250a8-e860-413e-b16b-1f83c72a79ad', '8d445cdf-0f39-45e7-8bc1-787b404be2d1', 3);
INSERT INTO public.playlist_items VALUES ('9f2df54d-f5f2-4192-b63f-878990857703', '00fa64fe-552c-4bad-ba33-52d98b4962b0', '07022b1c-9e02-4a30-8860-c2b2a680a747', 0);
INSERT INTO public.playlist_items VALUES ('9f2df54d-f5f2-4192-b63f-878990857703', '00ca3f6a-4433-4915-8bef-a885bd7451cd', '0b680f4d-0acf-4468-90bc-1c8270523e25', 1);
INSERT INTO public.playlist_items VALUES ('9f2df54d-f5f2-4192-b63f-878990857703', '0003b274-e31f-448a-8c7c-66085e76a0e3', 'f149d857-bf82-4230-af3c-377f0f740c6f', 2);
INSERT INTO public.playlist_items VALUES ('9f2df54d-f5f2-4192-b63f-878990857703', '0143616c-4440-472d-8173-25d4f2de23b0', '06134631-c006-4cfe-bdd0-b159e6a8ab1d', 3);
INSERT INTO public.playlist_items VALUES ('9f2df54d-f5f2-4192-b63f-878990857703', '0124bed4-c0e8-4328-90d7-672b14dde366', 'a4477623-1a58-46b7-b2af-41dd2335383c', 4);
INSERT INTO public.playlist_items VALUES ('ecff3731-79cc-41f9-a355-839b5065231f', '0003b274-e31f-448a-8c7c-66085e76a0e3', 'f149d857-bf82-4230-af3c-377f0f740c6f', 0);
INSERT INTO public.playlist_items VALUES ('ecff3731-79cc-41f9-a355-839b5065231f', '01314972-e200-4b7e-8913-17aa834db739', '15fee565-9384-4132-913f-f53cf7615bb3', 1);
INSERT INTO public.playlist_items VALUES ('ecff3731-79cc-41f9-a355-839b5065231f', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'f6306e1d-171d-4fc0-b749-687a6a47beae', 2);
INSERT INTO public.playlist_items VALUES ('986b2a8b-be30-478c-a431-4fb8b6c1c110', '00ca3f6a-4433-4915-8bef-a885bd7451cd', '0b680f4d-0acf-4468-90bc-1c8270523e25', 1);
INSERT INTO public.playlist_items VALUES ('986b2a8b-be30-478c-a431-4fb8b6c1c110', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', '520ef14d-8ff0-4968-866a-b8de41308c9d', 2);
INSERT INTO public.playlist_items VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '0003b274-e31f-448a-8c7c-66085e76a0e3', '2184c7a0-8453-498b-b5e4-7f066b2718b9', 0);
INSERT INTO public.playlist_items VALUES ('39ab9ef7-b23d-49d7-8f89-f15834954aa6', '01314972-e200-4b7e-8913-17aa834db739', '15fee565-9384-4132-913f-f53cf7615bb3', 0);
INSERT INTO public.playlist_items VALUES ('39ab9ef7-b23d-49d7-8f89-f15834954aa6', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', 'aa22609b-f146-4aa7-a34c-2ed655e4c74e', 1);
INSERT INTO public.playlist_items VALUES ('39ab9ef7-b23d-49d7-8f89-f15834954aa6', '00e19ded-d904-41eb-abec-fea60fc5b747', '64661631-8bd2-4055-a273-ffdb01baf54c', 2);
INSERT INTO public.playlist_items VALUES ('39ab9ef7-b23d-49d7-8f89-f15834954aa6', '001587f5-8fbd-4ec1-9a16-cf64ebca63dc', '520ef14d-8ff0-4968-866a-b8de41308c9d', 3);
INSERT INTO public.playlist_items VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '0076de74-abf3-40c1-8b02-e58f2987a985', 'd8d7dc78-d8d2-473d-ad80-b9bbe22e9dd8', 1);
INSERT INTO public.playlist_items VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '009250a8-e860-413e-b16b-1f83c72a79ad', '3078894e-2fdc-47d2-8dfa-dc2a9794a895', 4);
INSERT INTO public.playlist_items VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '004c71d6-d81f-4f72-b585-554311133070', '5a59f78f-f3f3-4f0b-9e86-ae50261c6786', 6);
INSERT INTO public.playlist_items VALUES ('575847d5-35f3-4100-a7a4-a59bccde82eb', '00a29fc8-e728-4274-9cc8-558374195c04', 'ed31f1af-3f37-4911-ae2d-212bdf82a4d5', 0);
INSERT INTO public.playlist_items VALUES ('575847d5-35f3-4100-a7a4-a59bccde82eb', '003c0fac-7c52-439a-b397-688ab192758d', 'e3072007-cb6f-4be9-822a-c596801b962a', 1);
INSERT INTO public.playlist_items VALUES ('575847d5-35f3-4100-a7a4-a59bccde82eb', '011fe00f-ac6f-4df9-9b4b-475385c54db8', 'af7743b2-d3d6-42b2-8363-20849b2919d6', 2);


--
-- Data for Name: playlists; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.playlists VALUES ('2643a351-f908-4f24-a922-6798d70d804d', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', '064c4ae2-81cd-49dc-ae38-bc7cd121f54e', '', false, 'Aaa Playlist', true, NULL, NULL);
INSERT INTO public.playlists VALUES ('06635238-1390-434e-aff5-2c5964cd8b2f', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', '38b5ba88-5a26-46de-81f6-fc4d4d361bb5', '', false, 'Artist Playlist', false, NULL, NULL);
INSERT INTO public.playlists VALUES ('5328ddfd-b47b-40a4-a8c9-3de8f11ec283', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', '38b5ba88-5a26-46de-81f6-fc4d4d361bb5', '', false, 'Second Artist Playlist', false, NULL, NULL);
INSERT INTO public.playlists VALUES ('8dc0a933-f7dc-47d8-a32c-2e9474a0c5be', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', '064c4ae2-81cd-49dc-ae38-bc7cd121f54e', '', false, 'Public Playlist', true, NULL, NULL);
INSERT INTO public.playlists VALUES ('da0a371a-addd-4ffe-b2f9-7be8c7058f22', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', '38b5ba88-5a26-46de-81f6-fc4d4d361bb5', '', false, 'ZZZ Artist''s Playlist', true, NULL, NULL);
INSERT INTO public.playlists VALUES ('ee0e6db1-88c0-40bd-8c4f-aedb07eb0854', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', 'a72bf5ed-9ad3-4ad1-bc86-5db72395f6ae', '', false, 'Z Playlist', false, NULL, NULL);
INSERT INTO public.playlists VALUES ('dcbc8e35-33ca-4113-b720-7b41f62695cc', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', 'a72bf5ed-9ad3-4ad1-bc86-5db72395f6ae', '', false, 'A Playlist', false, NULL, NULL);
INSERT INTO public.playlists VALUES ('ecccd368-0fe5-4b44-abdc-e5796efe3418', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', 'a72bf5ed-9ad3-4ad1-bc86-5db72395f6ae', '', false, 'My Library', false, NULL, NULL);
INSERT INTO public.playlists VALUES ('bbfc9b47-fde0-4959-ba76-6e871460abaf', '2020-01-29 05:26:30.017348-08', '2020-01-29 05:26:30.017348-08', 'a72bf5ed-9ad3-4ad1-bc86-5db72395f6ae', '', false, 'Public No Records', true, NULL, NULL);
INSERT INTO public.playlists VALUES ('1b605130-c810-4f50-a6b2-3305f669d88a', '2021-04-21 19:07:07.440057-07', '2021-04-21 19:07:07.440058-07', 'a64b89e5-ed32-424e-9a0a-612290814eb2', '', false, 'My Library', false, NULL, NULL);
INSERT INTO public.playlists VALUES ('d7261671-2899-4ccc-8bb4-797a3e115260', '2021-04-21 21:50:11.598251-07', '2021-04-21 21:50:11.598251-07', 'a64b89e5-ed32-424e-9a0a-612290814eb2', '', false, '123', false, NULL, NULL);
INSERT INTO public.playlists VALUES ('ecff3731-79cc-41f9-a355-839b5065231f', '2021-04-21 22:07:45.246141-07', '2021-04-21 22:07:48.205668-07', NULL, 'Deepest House Tunes!', false, 'Deep house', true, 'c4e8ea82-05a0-4015-b0f1-0a8bf4b81b8a', NULL);
INSERT INTO public.playlists VALUES ('9bf60a93-a54f-49c6-b243-c7df9469511d', '2021-04-21 22:08:01.864292-07', '2021-04-21 22:08:01.864292-07', NULL, 'Best hits of all time.', false, 'Greatest Hits', true, NULL, NULL);
INSERT INTO public.playlists VALUES ('6476fd90-8b48-4dd7-8ae8-1ee7e39e5ad4', '2021-04-21 22:12:08.718818-07', '2021-04-21 22:12:50.273358-07', NULL, 'Gaming Tunes!', false, 'Monstercat Gaming', true, '71f3e46c-17c4-4253-a218-cbd9ef867961', NULL);
INSERT INTO public.playlists VALUES ('b430c9a7-a3af-4cdd-a606-1efae2a0f0c9', '2021-04-21 22:14:35.344154-07', '2021-04-21 22:14:38.975126-07', NULL, 'Relaxing Electronic music.', false, 'Relaxing Electronic', true, '0280392e-282c-48aa-8db6-dd16c0e2e618', NULL);
INSERT INTO public.playlists VALUES ('92b73dcc-f5f0-45c9-ae20-941d2706cba8', '2021-04-21 22:14:52.872972-07', '2021-04-21 22:14:58.225188-07', NULL, 'Roblox Playlist for Roblox players.', false, 'Roblox Playlist', true, '2e624f15-b7ad-4666-9f72-7623d8f14525', NULL);
INSERT INTO public.playlists VALUES ('b1425bd9-bd2e-4224-a84e-a68dab27d70e', '2021-04-21 22:15:42.490238-07', '2021-04-21 22:15:45.974139-07', NULL, 'Soccer on wheels music', false, 'Rocket League playlist', true, '05ef6115-8ba1-48a9-8c76-93d376cfb52a', NULL);
INSERT INTO public.playlists VALUES ('986b2a8b-be30-478c-a431-4fb8b6c1c110', '2021-04-21 22:16:32.640934-07', '2021-04-21 22:16:36.394501-07', NULL, 'Music from a summertime house!', false, 'Summertime House', true, 'bdda3a68-28f5-4986-9b35-2c121f9d7b99', NULL);
INSERT INTO public.playlists VALUES ('e3536c6e-42f3-4193-a5ac-fe480b2221fa', '2021-04-21 22:10:41.746041-07', '2021-04-21 22:21:15.802443-07', NULL, 'Silky Tracks from Monstercat!', false, 'Best of Monstercat Silk', true, '00f1b4d5-28db-4c62-852f-dbf20542cc44', NULL);
INSERT INTO public.playlists VALUES ('69bb879e-fde5-4549-9cf7-d90c22207af5', '2021-04-21 22:06:49.159759-07', '2021-04-21 22:31:39.84255-07', NULL, 'Bassy Music', false, 'Bass Party', true, '9919837a-c835-4080-be66-0027717aae64', NULL);
INSERT INTO public.playlists VALUES ('39ab9ef7-b23d-49d7-8f89-f15834954aa6', '2021-04-21 22:14:08.209316-07', '2021-04-21 22:31:51.958491-07', NULL, 'Fortnite Music for Fortnite players!', false, 'Fortnite Music', true, '5eaa1d4f-0196-4454-ba08-7daf116bda0a', NULL);
INSERT INTO public.playlists VALUES ('2207d12c-b579-4522-a0b6-cdf494ab955e', '2021-04-21 22:13:09.521213-07', '2021-04-21 22:31:58.170655-07', NULL, 'House and Trance!', false, 'Progressive House & Trance', true, '1f74555a-e079-479f-a187-3faeb0b8a98a', NULL);
INSERT INTO public.playlists VALUES ('9a2c6f4e-81dd-431c-a71d-956266f2b1e5', '2021-04-21 22:13:34.099067-07', '2021-04-21 22:32:06.189936-07', NULL, 'EDM that is PUMPED UP!', false, 'Pumped Up EDM', true, '37459926-0d0f-423d-bc50-acf39bf15cd7', NULL);
INSERT INTO public.playlists VALUES ('9f2df54d-f5f2-4192-b63f-878990857703', '2021-04-21 22:07:21.547047-07', '2021-04-21 22:32:43.461603-07', NULL, 'Dancy Anthems!', false, 'Dance Anthems', true, 'b82b6316-132d-4ce1-9b26-88942d1c2774', NULL);
INSERT INTO public.playlists VALUES ('926b2986-16ae-4701-92c8-23071225e016', '2021-04-21 22:10:16.707675-07', '2021-04-21 22:10:16.707675-07', NULL, 'Tracks from our Instinct brand!', false, 'Instinct', true, NULL, NULL);
INSERT INTO public.playlists VALUES ('cb39633e-89e5-4587-81ca-9d36da3563d5', '2021-04-21 22:16:02.061665-07', '2021-04-21 22:16:08.829354-07', NULL, 'Silk Silk Silk Silk Silk Silk Silk Silk Silk Silk Silk Silk Silk Silk!', false, 'Silk', true, '6fa43269-4d73-40f2-8948-6ea27311263a', NULL);
INSERT INTO public.playlists VALUES ('575847d5-35f3-4100-a7a4-a59bccde82eb', '2021-04-21 22:16:49.712003-07', '2021-04-21 22:16:49.712003-07', NULL, 'Music from our uncaged brand.', false, 'Uncaged', true, NULL, NULL);


--
-- Data for Name: podcast_stations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.podcast_stations VALUES ('98313053-420d-465f-ae23-fc181020c394', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'cd80238d-a1e2-48b8-97b6-7c00b46a3b2e', 'Love Dance Radio', 'Weekly', '', 'https://www.lovedanceradio.com.au/', 11);
INSERT INTO public.podcast_stations VALUES ('859d38e9-56e8-44fc-88c3-fc261e7d3818', 'fefef21d-7746-4751-8ee8-d2e86c124695', 'cd80238d-a1e2-48b8-97b6-7c00b46a3b2e', 'Digitally Imported', '8AM PT - Thurs', 'https://assets.monstercat.com/podcast/stations/icon_difm.png', 'https://www.di.fm/shows/silk-music-showcase', 0);
INSERT INTO public.podcast_stations VALUES ('6cc72220-2979-4b87-99a9-619c64f35c8e', 'fefef21d-7746-4751-8ee8-d2e86c124695', 'cd80238d-a1e2-48b8-97b6-7c00b46a3b2e', 'istream', '3AM PT - Fri', 'https://www.monstercat.com/podcasts/mss/station%20logos/icon_istreem2.png', 'https://istreemradio.com/', 3);
INSERT INTO public.podcast_stations VALUES ('e12369ef-3b78-4117-8e46-fcb1e8bd1157', '9b46841b-1854-4c6b-918d-149b8f53b81d', '053d155a-cb9f-4ed1-84a4-2a44fccedb01', 'Anghami', 'On Demand', 'https://assets.monstercat.com/podcast/stations/icon_anghami.png', 'http://monster.cat/2xyDjeE', 19);
INSERT INTO public.podcast_stations VALUES ('4c74cb84-84ba-4146-bea9-3c19da00bfbc', 'fefef21d-7746-4751-8ee8-d2e86c124695', 'cd80238d-a1e2-48b8-97b6-7c00b46a3b2e', 'Yes FM', '1:30PM PT - Fri', 'https://assets.monstercat.com/podcast/mss/icon_yes101.png', 'http://www.yesfmonline.com/index.php/programs', 1);
INSERT INTO public.podcast_stations VALUES ('96651cd2-fc2f-4317-b4ac-8ef002f9e147', 'fefef21d-7746-4751-8ee8-d2e86c124695', 'cd80238d-a1e2-48b8-97b6-7c00b46a3b2e', 'Get Lifted', '9am PT - Thurs', 'https://assets.monstercat.com/podcast/mss/icon_get-lifted.png', 'https://wegetliftedradio.com/', 2);
INSERT INTO public.podcast_stations VALUES ('90322f2c-bc41-4763-aa8d-ecab38162b31', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'cd80238d-a1e2-48b8-97b6-7c00b46a3b2e', 'Livestream Premiere', 'Weds - 1PM PDT', 'https://assets.monstercat.com/podcast/stations/icon_livestream.png', 'http://live.monstercat.com/', 0);
INSERT INTO public.podcast_stations VALUES ('916394a3-b73c-4ce6-a114-72b37a88d92c', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'be141d5e-d0a2-4e4e-ae17-eae4e91309ec', 'Noise FM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_noisefm.png', 'http://monster.cat/29QgtB4', 8);
INSERT INTO public.podcast_stations VALUES ('fcd6aa8f-12e9-4c78-a073-7a86a0c1dd28', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'c453d9e0-27da-49d0-9e4b-b72ee69d6fc1', 'My 95.9 FM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_959.png', 'http://monster.cat/2abSoq9', 10);
INSERT INTO public.podcast_stations VALUES ('72ab0b61-2011-4b20-a712-bc9d3540ff2b', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'a06df5ae-21bf-471c-b85a-1cd090dea53d', 'Dance 97.8', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_dance978.png', 'http://monster.cat/2fDkXiL', 15);
INSERT INTO public.podcast_stations VALUES ('f7efb7c8-d374-4e48-8c34-28f9ae976251', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'be141d5e-d0a2-4e4e-ae17-eae4e91309ec', 'Radio SK 90.2 FM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_SK.png', 'http://monster.cat/2xyAQ4a', 16);
INSERT INTO public.podcast_stations VALUES ('2826f4d6-0cf6-4258-95f5-06db2b592630', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'a977fcf2-a1b4-4168-b9d1-6801e46da156', 'Real Dance Radio', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_real.png', 'http://monster.cat/2axYz9r', 18);
INSERT INTO public.podcast_stations VALUES ('c38c9c15-35ec-40c2-b897-c36953d87a15', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'b36bc5cf-77d8-490c-928e-91561eab9ca8', 'Radio FG', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_FG.png', 'http://monster.cat/2w9WxUp', 20);
INSERT INTO public.podcast_stations VALUES ('f22b8fde-ca07-4c3c-8d95-918375c61f12', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'c0f40581-3d77-4b27-a013-90205ef5954f', 'Dubbase FM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_dubbase.png', 'http://monster.cat/2bArO84', 25);
INSERT INTO public.podcast_stations VALUES ('9379e23a-13f0-4d32-99cb-000955bcbf4f', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'b533b357-67ff-452c-b706-9e9c2ac57093', 'Kiss FM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_kiss.png', 'http://kissthailand.asia/', 26);
INSERT INTO public.podcast_stations VALUES ('e532fa61-646a-46c7-be6c-ab34b743d384', '9b46841b-1854-4c6b-918d-149b8f53b81d', '9eae7849-cf6c-45af-a0cd-2324f4ce3ef5', 'Switch 119.7', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_switch.png', 'http://monster.cat/2dtBhzo', 27);
INSERT INTO public.podcast_stations VALUES ('4d546d8c-6b26-461b-bf80-59db4814cf3c', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'a47a9169-d075-446c-8a19-1955ca1548d2', 'Dirty Beats Radio', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_dirty.png', '', 28);
INSERT INTO public.podcast_stations VALUES ('575a2c29-90ab-486a-893a-f309476eb5cd', '9b46841b-1854-4c6b-918d-149b8f53b81d', '48d5dc4a-d238-4e05-87a4-3e61fce84eb0', 'Radio5', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_radio5.png', 'http://monster.cat/2a00QXk', 24);
INSERT INTO public.podcast_stations VALUES ('c7e12aec-b154-4e75-b404-4cfd2015886c', '9b46841b-1854-4c6b-918d-149b8f53b81d', '90af41ba-3fdf-4eb1-aff4-080a0b717b7e', 'Diplo''s Revolution - SiriusXM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_diplo_sirius.png', 'https://siriusxm.us/diplo52', 1);
INSERT INTO public.podcast_stations VALUES ('c4d2d5aa-b3e5-4c5a-bee3-ee3bef07ee31', '9b46841b-1854-4c6b-918d-149b8f53b81d', '0887d2af-fa29-4afd-94da-30d88f4eb3f2', '101.7 Radio Shanghai', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_shanghai-101.png', 'http://rs.ajmide.com/r_11/11.m3u8', 2);
INSERT INTO public.podcast_stations VALUES ('2fd4c48d-35c8-4738-a1d8-19eca64af223', '9b46841b-1854-4c6b-918d-149b8f53b81d', '0887d2af-fa29-4afd-94da-30d88f4eb3f2', 'HitFM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_hitfm.png', 'https://streema.com/radios/CRI_Hit_FM', 3);
INSERT INTO public.podcast_stations VALUES ('bf731095-f964-4b4d-b217-e3331ce2e874', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'a977fcf2-a1b4-4168-b9d1-6801e46da156', 'Digitally Imported', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_difm.png', 'http://monster.cat/2wKdt3s', 4);
INSERT INTO public.podcast_stations VALUES ('0cb8f3c0-b30a-43b0-946a-f76d502b7fbe', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'c0f40581-3d77-4b27-a013-90205ef5954f', 'I Love Music', '24 / 7', 'https://assets.monstercat.com/podcast/stations/icon_ilm.png', 'https://www.ilovemusic.de/ilovemonstercat/', 5);
INSERT INTO public.podcast_stations VALUES ('81c457f9-ccf5-46c9-9d53-0c5a5acdcddf', '9b46841b-1854-4c6b-918d-149b8f53b81d', '85bc4ec8-c65e-49aa-8762-978118c64df7', '7FM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_7FM.png', 'http://monster.cat/2fCjoBJ', 6);
INSERT INTO public.podcast_stations VALUES ('f7539ee5-7b0b-4e35-b295-bb44d57e703f', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'de988578-8161-451b-83bb-2e5dc17d8493', 'Afterclub', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_aftercluv.png', 'http://monster.cat/2jOesOT', 7);
INSERT INTO public.podcast_stations VALUES ('f05e8a28-4a2a-46f9-97cb-6eb74c2f3aa6', '9b46841b-1854-4c6b-918d-149b8f53b81d', '86b416cf-157b-4d48-a6d2-61a2dd805f87', 'Electra FM', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_electra.png', 'http://monster.cat/29Wwu9i', 9);
INSERT INTO public.podcast_stations VALUES ('c07d5eeb-fa6e-4614-90c0-6df7d99fc1c3', '9b46841b-1854-4c6b-918d-149b8f53b81d', '0887d2af-fa29-4afd-94da-30d88f4eb3f2', 'Pyro', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_pyro.png', 'http://monster.cat/2kyk1QJ', 12);
INSERT INTO public.podcast_stations VALUES ('b0a05176-d070-4571-bdbd-5b2737cfbaf2', '9b46841b-1854-4c6b-918d-149b8f53b81d', '90af41ba-3fdf-4eb1-aff4-080a0b717b7e', 'GrooveFox', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_groovefox.png', 'https://groovefox.com', 13);
INSERT INTO public.podcast_stations VALUES ('83a6e2f7-372f-4ce7-a190-b3aebf9fd5c8', '9b46841b-1854-4c6b-918d-149b8f53b81d', '38fe387c-07a6-4230-8c6d-761816071d46', 'Fuddle.NL', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_fuddle.png', 'http://monster.cat/29Y2yrD', 14);
INSERT INTO public.podcast_stations VALUES ('4ca5518c-ce9e-44e7-b426-e3e67230e509', '9b46841b-1854-4c6b-918d-149b8f53b81d', '2460aaf3-8a2b-4a3a-acff-23377ecb93da', 'My 105', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_105.png', 'http://monster.cat/2fDLGLg', 17);
INSERT INTO public.podcast_stations VALUES ('818f5df8-392e-48d4-9778-8f44a2e07443', '9b46841b-1854-4c6b-918d-149b8f53b81d', '544e0cea-5e46-4098-8f6a-b5a0a767ee8c', '401 Radio', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_401.png', 'http://monster.cat/1KrxhtM', 21);
INSERT INTO public.podcast_stations VALUES ('6d793ded-38ca-46fb-bdf6-6d024a7f6dc9', '9b46841b-1854-4c6b-918d-149b8f53b81d', '544e0cea-5e46-4098-8f6a-b5a0a767ee8c', 'Dance Radio', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_dance.png', 'http://monster.cat/29Y37kZ', 22);
INSERT INTO public.podcast_stations VALUES ('113604df-3bc7-4161-a93d-0733e49d7fcf', '9b46841b-1854-4c6b-918d-149b8f53b81d', 'a977fcf2-a1b4-4168-b9d1-6801e46da156', 'Wizard Radio', 'Weekly', 'https://assets.monstercat.com/podcast/stations/icon_wizard.png', 'http://monster.cat/2a3wZ37', 23);


--
-- Data for Name: podcasts; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.podcasts VALUES ('fefef21d-7746-4751-8ee8-d2e86c124695', 'Monstercat Silk Showcase is our weekly radio show & podcast, featuring emotive and intelligent house, progressive, trance, & chillout. Label Director Jacob Henry and residents Tom Fall, Jayeson Andel, Terry Da Libra, Vintage & Morelli, A.M.R, and Sundriver co-host the show.  ⁣ We invite you to experience each new episode of our show every Wednesday at 2pm PT, starting February 17, 2021.', '{https://open.spotify.com/playlist/63wXzEzAf4jH24JjMMhWM7?si=IE5UXizMT6ijwbJNKZAldA,https://podcasts.apple.com/ca/podcast/silk-music-showcase/id359588988,https://podcasts.google.com/feed/aHR0cDovL2ZlZWRzLmZlZWRidXJuZXIuY29tL1NpbGtSb3lhbFNob3djYXNl?hl=en-CA,https://music.amazon.ca/podcasts/90f9c9ea-b0a0-4401-b222-c5a4ff85b345/Monstercat-Silk-Showcase,https://www.mixcloud.com/monstercat/,https://www.stitcher.com/show/silk-music-showcase-2,https://castbox.fm/channel/Silk-Music-Showcase-id2114721?country=us}', 'About Monstercat Silk Showcase', 5, 'mss');
INSERT INTO public.podcasts VALUES ('9b46841b-1854-4c6b-918d-149b8f53b81d', 'An unbound exploration of sound with the latest electronic music. Join thousands of people across the globe who are ready to break free from anything ordinary. Featuring unreleased previews, artist takeovers, and an immersive community. Whether partying, studying, or dreaming of the next big thing, these are the songs that define your journey into the wild. <br><br> New episodes every Wednesday 1PM PT / 4PM ET / 10PM CEST', '{https://open.spotify.com/playlist/15bT8fa0BPaYHN9VZRmJCN?si=QRj83V51SiGFBiUdRWnggg,https://podcasts.apple.com/ca/podcast/monstercat-call-of-the-wild/id840803139,https://podcasts.google.com/?feed=aHR0cHM6Ly93d3cubW9uc3RlcmNhdC5jb20vcG9kY2FzdC9mZWVkLnhtbA&ved=2ahUKEwj4iZfwutLpAhWWmZ4KHQOYBncQ4aUDegQIARAC&hl=en-CA,https://music.amazon.ca/podcasts/fca6730c-fc93-4e5c-82a9-60d914ffca7d/MONSTERCAT-CALL-OF-THE-WILD,https://soundcloud.com/monstercat/sets/monstercat-podcast,https://www.mixcloud.com/monstercat/,https://castbox.fm/channel/Monstercat%3A-Call-of-the-Wild-id6404?utm_source=website&utm_medium=dlink&utm_campaign=web_share&utm_content=Monstercat%3A%20Call%20of%20the%20Wild-CastBox_FM,https://www.stitcher.com/podcast/monstercat-call-of-the-wild}', 'About Call of The Wild ', 3, 'cotw');


--
-- Data for Name: poll_options; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.poll_options VALUES ('c89cf076-b4f4-4b11-a57a-bb84baac157f', 'Terrance (Week 2)', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 1, NULL, NULL);
INSERT INTO public.poll_options VALUES ('6075c7db-76e3-4b6b-a1b0-96cd1c41bc3c', 'Clarissa (Week 2)', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 2, NULL, NULL);
INSERT INTO public.poll_options VALUES ('ec0c9e58-ea33-4a44-9415-78f748fe6b2d', 'Jamothy (Week 2)', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 3, NULL, NULL);
INSERT INTO public.poll_options VALUES ('1f602f55-44e1-45c7-affc-6db7ba8d7042', 'Option for Other Poll', '3217c48d-0bfb-4ff8-ae9e-ba3c074774ba', 1, NULL, NULL);

INSERT INTO public.poll_options VALUES ('f26bd536-eb88-40b3-8ce2-0bca8eb66da2', 'Monstercat Podcast Ep. 151  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Monstercat Podcast Ep. 151", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "c9c3192a-bf2d-466b-9aa4-63772f97eddc", "Version": "", "CatalogID": "MCP151", "ReleaseID": "0083b1e3-a052-4568-b615-9b5c370d5269", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('7f42a76c-2750-4410-855f-bdedd60ba2dc', 'Monstercat Podcast Ep. 084  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Monstercat Podcast Ep. 084", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "9002a5de-0202-46b9-b0ff-479a147bbc33", "Version": "", "CatalogID": "MCP084", "ReleaseID": "01a23cd5-65e7-4157-b5a0-cf873b7218d2", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('01a279f9-b992-4517-b767-b3d04dce089a', 'Your Pain The Prototypes Remix - Koven', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Your Pain", "Artists": [{"ID": "f90bf89c-d051-4a46-81b9-09d585ec4a35", "URI": "koven", "Name": "Koven", "TwitterHandle": "https://twitter.com/KOVENuk"}, {"ID": "da513319-712a-4dfb-8a24-368aa1bfc748", "URI": "the-prototypes", "Name": "The Prototypes", "TwitterHandle": "https://twitter.com/ThePrototypesUK"}], "TrackID": "79fe14a7-dbfe-4783-9457-ea8e244d67a9", "Version": "The Prototypes Remix", "CatalogID": "MCLP015X-3", "ReleaseID": "0128ee2a-225e-48e4-a915-759ee6ff298e", "ArtistsTitle": "Koven"}');
INSERT INTO public.poll_options VALUES ('dab0f6f6-a228-46ec-b866-2e21cc98c310', '280 - Monstercat: Call of the Wild  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "280 - Monstercat: Call of the Wild", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "e7ab79fa-ed6a-4984-9020-c17c500506ba", "Version": "", "CatalogID": "COTW280", "ReleaseID": "01b397cd-cc49-46f8-bd0c-bca510c56112", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('aa779890-5ac6-426e-a9fc-2032c6cf5e0f', 'Seashells  - Johan Vilborg', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Seashells", "Artists": [{"ID": "fd9ff2a7-e860-48ba-a201-234f54410d24", "URI": "johanvilborg", "Name": "Johan Vilborg", "TwitterHandle": "http://twitter.com/johanvilborg"}], "TrackID": "bd2fb527-f7c9-414f-846e-612c3955a164", "Version": "", "CatalogID": "SILKAC10", "ReleaseID": "02b48f83-e984-4812-95af-26082373fa50", "ArtistsTitle": "Johan Vilborg"}');
INSERT INTO public.poll_options VALUES ('45ce0810-258b-42be-a6c0-8fe2386f21ae', '271 - Monstercat: Call of the Wild  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "271 - Monstercat: Call of the Wild", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "687bf619-b37f-43fe-81c7-0f40cb5976f3", "Version": "", "CatalogID": "COTW271", "ReleaseID": "00415d8f-248f-4f18-9fb6-146ac0ee0c16", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('61646086-0cb0-4cec-a9cb-acfaeb03ef06', 'Winter  - Stephen Walking', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Winter", "Artists": [{"ID": "9581f755-5b54-4876-856a-ffc4a6792b7f", "URI": "stephenwalking", "Name": "Stephen Walking", "TwitterHandle": "http://twitter.com/stephenxwalking"}], "TrackID": "16f9d527-d8fe-4cf4-ae92-983b6e92e490", "Version": "", "CatalogID": "MCEP002", "ReleaseID": "0357d0cc-5480-4301-ba1c-29179a53a9d8", "ArtistsTitle": "Stephen Walking"}');
INSERT INTO public.poll_options VALUES ('180d1329-d3fd-46e3-9434-4ac553c6c767', 'Melancholy Strings  - Sound Quelle', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Melancholy Strings", "Artists": [{"ID": "89768a42-cea4-4814-afe3-522fdc7d6d9c", "URI": "sound-quelle", "Name": "Sound Quelle", "TwitterHandle": "https://twitter.com/SoundQuelle"}], "TrackID": "614d9d63-b6ae-427e-9a7f-5edc8c07597b", "Version": "", "CatalogID": "MCEP239", "ReleaseID": "0174a24a-d1e8-461f-9e80-7f30c6727616", "ArtistsTitle": "Sound Quelle"}');
INSERT INTO public.poll_options VALUES ('2c57fa7f-369c-46a0-ae72-f7015d28f441', 'Melancholy Strings Extended Mix - Sound Quelle', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Melancholy Strings", "Artists": [{"ID": "89768a42-cea4-4814-afe3-522fdc7d6d9c", "URI": "sound-quelle", "Name": "Sound Quelle", "TwitterHandle": "https://twitter.com/SoundQuelle"}], "TrackID": "4b60e5d2-49d3-44ae-9cde-ff0876bb6af9", "Version": "Extended Mix", "CatalogID": "MCEP239", "ReleaseID": "0174a24a-d1e8-461f-9e80-7f30c6727616", "ArtistsTitle": "Sound Quelle"}');
INSERT INTO public.poll_options VALUES ('57920556-9335-44c7-9356-a955bc3a72a2', 'BARRICADE  - REAPER', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "BARRICADE", "Artists": [{"ID": "205703f0-26b2-4f31-9663-7cb8d2d856fc", "URI": "reaper", "Name": "REAPER", "TwitterHandle": "https://twitter.com/reapernoises"}], "TrackID": "60dad350-8fd5-44f9-b917-afe1eb5e0ee0", "Version": "", "CatalogID": "MCS978", "ReleaseID": "01a7bcbc-afea-4fe2-81e3-8809ee3ae2fc", "ArtistsTitle": "REAPER"}');
INSERT INTO public.poll_options VALUES ('fa3f307e-33e7-4c25-9460-10fb5aa31c3a', 'Cave Me In  - FWLR & A-SHO', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Cave Me In", "Artists": [{"ID": "867149bb-b835-4258-8fde-c735966e16cf", "URI": "asho", "Name": "A-SHO", "TwitterHandle": "https://twitter.com/ashoofficial"}, {"ID": "26928ef7-b458-4511-ba9a-5d2fb0adf41a", "URI": "fwlr", "Name": "FWLR", "TwitterHandle": "https://twitter.com/fwlrmusic"}], "TrackID": "89e016b3-cab2-411b-824c-cc8261f163b0", "Version": "", "CatalogID": "MCS796", "ReleaseID": "0085a9bc-e58d-4b97-bc07-5e161d2bc3d6", "ArtistsTitle": "FWLR & A-SHO"}');
INSERT INTO public.poll_options VALUES ('45a28c22-efdc-44b1-a7f9-597b8b3f95e2', 'Fall  - Johan Vilborg', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Fall", "Artists": [{"ID": "fd9ff2a7-e860-48ba-a201-234f54410d24", "URI": "johanvilborg", "Name": "Johan Vilborg", "TwitterHandle": "http://twitter.com/johanvilborg"}], "TrackID": "df053894-f90f-463b-8916-7752aadaf91b", "Version": "", "CatalogID": "SILKAC10", "ReleaseID": "02b48f83-e984-4812-95af-26082373fa50", "ArtistsTitle": "Johan Vilborg"}');
INSERT INTO public.poll_options VALUES ('554ae1ad-fffa-448f-9a43-01253ced46c3', 'Have Fun  - Rameses B', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Have Fun", "Artists": [{"ID": "23791249-11ea-4e16-b3b2-41b29f9a34c0", "URI": "ramesesb", "Name": "Rameses B", "TwitterHandle": "https://twitter.com/ramesesb"}], "TrackID": "126b0274-9a78-45c0-9b45-41c5da35e287", "Version": "", "CatalogID": "MCS1231", "ReleaseID": "01103078-a2ab-4226-98ea-ea6f2b2e2c3d", "ArtistsTitle": "Rameses B"}');
INSERT INTO public.poll_options VALUES ('fa9f6dcc-a886-4f2a-a132-92601a8bb186', 'Anagenesis  - Terry Da Libra', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Anagenesis", "Artists": [{"ID": "8f70d53a-5df9-4e4b-aa97-770e956dbb18", "URI": "terry-da-libra", "Name": "Terry Da Libra", "TwitterHandle": "https://twitter.com/terrydalibra"}], "TrackID": "0959c22a-d448-464d-bd6e-5bf1ee43e23a", "Version": "", "CatalogID": "SILKM039", "ReleaseID": "01a1bcf9-f196-4d32-9ca2-fbd64d2ba35e", "ArtistsTitle": "Terry Da Libra"}');
INSERT INTO public.poll_options VALUES ('d36f6162-11c0-4f99-aed1-9503c1b3677a', 'Arp of Astronomical Wisdom  - Julian Calor', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Arp of Astronomical Wisdom", "Artists": [{"ID": "7d238f1b-63bb-4243-9722-06ac1af664f8", "URI": "juliancalor", "Name": "Julian Calor", "TwitterHandle": "https://twitter.com/JulianCalorDJ"}], "TrackID": "0d5f39f4-fd30-4f64-bcaf-ee204ec58897", "Version": "", "CatalogID": "MCS1004", "ReleaseID": "01474740-e155-458c-83cc-fb284a0401a7", "ArtistsTitle": "Julian Calor"}');
INSERT INTO public.poll_options VALUES ('fb9369ea-d84c-419d-8675-d6b9d6aba7b7', 'Cobra  - Sound Quelle', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Cobra", "Artists": [{"ID": "89768a42-cea4-4814-afe3-522fdc7d6d9c", "URI": "sound-quelle", "Name": "Sound Quelle", "TwitterHandle": "https://twitter.com/SoundQuelle"}], "TrackID": "74883ec9-4462-432c-b7ec-49c858255cae", "Version": "", "CatalogID": "SILKM225", "ReleaseID": "008dbc48-5c7a-4791-a16e-7c31864c4c90", "ArtistsTitle": "Sound Quelle"}');
INSERT INTO public.poll_options VALUES ('4ea19489-f010-43b5-adc2-e26179801472', 'That Morning  - Johan Vilborg', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "That Morning", "Artists": [{"ID": "fd9ff2a7-e860-48ba-a201-234f54410d24", "URI": "johanvilborg", "Name": "Johan Vilborg", "TwitterHandle": "http://twitter.com/johanvilborg"}], "TrackID": "ab4fb972-fcb7-4558-8b4f-11a8bb7b0ae6", "Version": "", "CatalogID": "SILKAC10", "ReleaseID": "02b48f83-e984-4812-95af-26082373fa50", "ArtistsTitle": "Johan Vilborg"}');
INSERT INTO public.poll_options VALUES ('ea7e8739-f69e-43c6-9c7a-520887fcc43a', 'Ripped To Pieces VIP - Stonebank feat. EMEL', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Ripped To Pieces", "Artists": [{"ID": "f69849e2-5e70-45ab-a7ba-d0acd7d75e8b", "URI": "stonebank", "Name": "Stonebank", "TwitterHandle": "https://twitter.com/stonebankmusic"}, {"ID": "cb1a0c99-0695-497e-8842-80e9d5698969", "URI": "emel", "Name": "EMEL", "TwitterHandle": "https://twitter.com/EmelMusicUK"}], "TrackID": "c2eeca99-9028-440a-a0ca-aed06a7bc8aa", "Version": "VIP", "CatalogID": "MCS937", "ReleaseID": "010dc6eb-32a1-4c5c-a6a0-213d6e1a6141", "ArtistsTitle": "Stonebank feat. EMEL"}');
INSERT INTO public.poll_options VALUES ('87428ceb-a3f1-4f09-9d9a-cb4bdb1ee6cd', 'Van Damme  - Sound Quelle & Referna', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Van Damme", "Artists": [{"ID": "89768a42-cea4-4814-afe3-522fdc7d6d9c", "URI": "sound-quelle", "Name": "Sound Quelle", "TwitterHandle": "https://twitter.com/SoundQuelle"}, {"ID": "586c1cd8-cdc6-43b5-8e23-6e98c9b1c417", "URI": "referna", "Name": "Referna", "TwitterHandle": "http://twitter.com/referna"}], "TrackID": "eab82d1b-d52a-43a0-8c72-0222e5bb271b", "Version": "", "CatalogID": "MCEP239", "ReleaseID": "0174a24a-d1e8-461f-9e80-7f30c6727616", "ArtistsTitle": "Sound Quelle & Referna"}');
INSERT INTO public.poll_options VALUES ('055ca230-5039-4d5e-90a7-cc4d2bf6f02a', 'Automaton  - Robotaki', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Automaton", "Artists": [{"ID": "58fb1dc2-a86b-464d-8940-2a1d3d40e13d", "URI": "robotaki", "Name": "Robotaki", "TwitterHandle": "https://twitter.com/Robotaki"}], "TrackID": "bcd6532e-d670-4e7e-9b9c-b151bdd4328f", "Version": "", "CatalogID": "MCS534", "ReleaseID": "020a9201-3843-4173-8efe-0e2a0201c8e0", "ArtistsTitle": "Robotaki"}');
INSERT INTO public.poll_options VALUES ('6a2fadbb-5552-4714-ad41-b35952d85feb', 'Warp Zone  - Nitro Fun', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Warp Zone", "Artists": [{"ID": "2ab3416b-aaea-4dc7-bcb2-cefceda8b72f", "URI": "nitrofun", "Name": "Nitro Fun", "TwitterHandle": "https://twitter.com/nitrofun"}], "TrackID": "4d7a79ad-20f5-4ecd-b002-8eef76caf615", "Version": "", "CatalogID": "MCS1082", "ReleaseID": "00928d4e-b111-4c6e-a5a3-ca60813cb868", "ArtistsTitle": "Nitro Fun"}');
INSERT INTO public.poll_options VALUES ('4cff83a4-5e49-4065-95d9-6364f956f38f', 'Epiphany  - Terry Da Libra', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Epiphany", "Artists": [{"ID": "8f70d53a-5df9-4e4b-aa97-770e956dbb18", "URI": "terry-da-libra", "Name": "Terry Da Libra", "TwitterHandle": "https://twitter.com/terrydalibra"}], "TrackID": "e4e96eab-f949-4ca4-b517-961970eccbc8", "Version": "", "CatalogID": "SILKM039", "ReleaseID": "01a1bcf9-f196-4d32-9ca2-fbd64d2ba35e", "ArtistsTitle": "Terry Da Libra"}');
INSERT INTO public.poll_options VALUES ('843523fb-2aa9-40b9-aa9a-83bf72791074', 'Van Damme Extended Mix - Sound Quelle & Referna', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Van Damme", "Artists": [{"ID": "89768a42-cea4-4814-afe3-522fdc7d6d9c", "URI": "sound-quelle", "Name": "Sound Quelle", "TwitterHandle": "https://twitter.com/SoundQuelle"}, {"ID": "586c1cd8-cdc6-43b5-8e23-6e98c9b1c417", "URI": "referna", "Name": "Referna", "TwitterHandle": "http://twitter.com/referna"}], "TrackID": "dc4db61f-4029-4ec1-b2d6-9ea21e43bda4", "Version": "Extended Mix", "CatalogID": "MCEP239", "ReleaseID": "0174a24a-d1e8-461f-9e80-7f30c6727616", "ArtistsTitle": "Sound Quelle & Referna"}');
INSERT INTO public.poll_options VALUES ('a9d4f033-8e97-4f98-b35e-2ce81cf225a3', 'Old Skool  - Televisor', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Old Skool", "Artists": [{"ID": "ef1faf3f-78a6-4f03-ad02-bd4598439e24", "URI": "televisor", "Name": "Televisor", "TwitterHandle": "http://twitter.com/televisormusic"}], "TrackID": "9e725eff-935f-409e-9c1a-d092fc98b114", "Version": "", "CatalogID": "MCS142", "ReleaseID": "00539c8e-7ec7-4c8d-8f09-8daca8bb8ae7", "ArtistsTitle": "Televisor"}');
INSERT INTO public.poll_options VALUES ('f1355a13-0e28-4d8a-a222-1b6b31114c4b', 'Monstercat Podcast Ep. 020  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Monstercat Podcast Ep. 020", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "38759ed3-112c-419c-a3fd-1aadce5422c4", "Version": "", "CatalogID": "MCP020", "ReleaseID": "004166ba-13c0-433b-9dad-4104dd784abe", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('98283565-9bea-47fc-9878-a99543f82e89', 'Peruan  - Sound Quelle', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Peruan", "Artists": [{"ID": "89768a42-cea4-4814-afe3-522fdc7d6d9c", "URI": "sound-quelle", "Name": "Sound Quelle", "TwitterHandle": "https://twitter.com/SoundQuelle"}], "TrackID": "1d3e1f6b-d6f0-45d6-acf5-43b173bc1a51", "Version": "", "CatalogID": "SILKM225", "ReleaseID": "008dbc48-5c7a-4791-a16e-7c31864c4c90", "ArtistsTitle": "Sound Quelle"}');
INSERT INTO public.poll_options VALUES ('643bd41b-a2ad-43bb-bb5d-490ed9e3292f', 'Voices  - Koven', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Voices", "Artists": [{"ID": "f90bf89c-d051-4a46-81b9-09d585ec4a35", "URI": "koven", "Name": "Koven", "TwitterHandle": "https://twitter.com/KOVENuk"}], "TrackID": "f72a0ed8-b727-43c3-b73a-60b95d802828", "Version": "", "CatalogID": "MCS722", "ReleaseID": "00928d30-7435-4a8a-9c32-5ed837363e42", "ArtistsTitle": "Koven"}');
INSERT INTO public.poll_options VALUES ('da785c41-14a4-4d3f-ae41-ae14be06b8d1', 'Scared  - Stonebank', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Scared", "Artists": [{"ID": "f69849e2-5e70-45ab-a7ba-d0acd7d75e8b", "URI": "stonebank", "Name": "Stonebank", "TwitterHandle": "https://twitter.com/stonebankmusic"}], "TrackID": "7e85eb2d-ccde-4c80-9877-2eacf4638e56", "Version": "", "CatalogID": "MCS1094", "ReleaseID": "002af073-f668-4f27-b302-4cd996633320", "ArtistsTitle": "Stonebank"}');
INSERT INTO public.poll_options VALUES ('f9648f5c-3c9f-47fa-8b19-62ab1e96a838', 'Shut My Mouth REAPER Remix - Koven', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Shut My Mouth", "Artists": [{"ID": "f90bf89c-d051-4a46-81b9-09d585ec4a35", "URI": "koven", "Name": "Koven", "TwitterHandle": "https://twitter.com/KOVENuk"}, {"ID": "205703f0-26b2-4f31-9663-7cb8d2d856fc", "URI": "reaper", "Name": "REAPER", "TwitterHandle": "https://twitter.com/reapernoises"}], "TrackID": "30d0fd1c-c64e-40ee-939b-f1dde3445a8b", "Version": "REAPER Remix", "CatalogID": "MCLP015X-12", "ReleaseID": "005e7326-daa3-4862-89ed-a6fbad206991", "ArtistsTitle": "Koven"}');
INSERT INTO public.poll_options VALUES ('a4a4e4cd-7647-44df-8ac7-311361ace221', 'Green Storm  - Favright', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Green Storm", "Artists": [{"ID": "102c1881-92aa-4a19-a273-56d481bad46d", "URI": "favright", "Name": "Favright", "TwitterHandle": "http://twitter.com/favright"}], "TrackID": "2db68de6-fc02-400e-befe-4f17a3864db6", "Version": "", "CatalogID": "MCS169", "ReleaseID": "034cb39c-62a0-45e1-a8bf-3b966a11c751", "ArtistsTitle": "Favright"}');
INSERT INTO public.poll_options VALUES ('6c9e73ab-f936-44bb-b357-6144ea691900', 'S6E3 - The Mix Contest - “Orbit”  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "S6E3 - The Mix Contest - “Orbit”", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "00db38f3-8fc8-420b-9927-ef1a7aa9a577", "Version": "", "CatalogID": "MMC603", "ReleaseID": "0195581f-47af-413c-ac74-8400543d014b", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('b6827063-9e30-4689-b283-fa64e83b9b63', '270 - Monstercat: Call of the Wild (Community Picks)  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "270 - Monstercat: Call of the Wild (Community Picks)", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "bf8d6206-3753-4a1d-8d66-b9239fb310b5", "Version": "", "CatalogID": "COTW270", "ReleaseID": "0092c04d-f1e5-48bc-9e41-aea9716b24cf", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('940f5983-bad3-4a49-a176-0aa7f338ba71', 'Let It Go  - Eptic & Dillon Francis', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Let It Go", "Artists": [{"ID": "ac6f00e9-7c97-496e-a470-85f7bbc2090e", "URI": "dillonfrancis", "Name": "Dillon Francis", "TwitterHandle": "https://twitter.com/dillonfrancis"}, {"ID": "62d27a16-24ee-4792-b066-1b583322d4c3", "URI": "eptic", "Name": "Eptic", "TwitterHandle": "https://twitter.com/eptic"}], "TrackID": "24ac6c31-71cb-45c9-94be-230874c43e7e", "Version": "", "CatalogID": "MCS874", "ReleaseID": "017ad50c-b88a-4b9a-af70-6f454bb1b9c5", "ArtistsTitle": "Eptic & Dillon Francis"}');
INSERT INTO public.poll_options VALUES ('968ab58e-f571-4c42-9714-13d20db00a00', 'Glow  - Shingo Nakamura', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Glow", "Artists": [{"ID": "47c6008f-910f-4b05-a65b-e193925ede9c", "URI": "shingo-nakamura", "Name": "Shingo Nakamura", "TwitterHandle": "https://twitter.com/_shingonakamura"}], "TrackID": "597b7a29-f2ed-4617-a308-587b66800868", "Version": "", "CatalogID": "MCS1129", "ReleaseID": "01464458-d20a-4cdc-bcf1-c1459831c6a1", "ArtistsTitle": "Shingo Nakamura"}');
INSERT INTO public.poll_options VALUES ('52250db1-5b9e-452d-be42-4454b153ba20', 'Nightfall  - Rogue', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Nightfall", "Artists": [{"ID": "e1475539-d1a9-46fb-b456-6f9a5847721f", "URI": "rogue", "Name": "Rogue", "TwitterHandle": "https://twitter.com/RogueMoosic"}], "TrackID": "fbf302b3-21c3-4964-8aa7-39471cda7418", "Version": "", "CatalogID": "MCS050", "ReleaseID": "02a97d18-3127-4622-88ac-c0281d814c36", "ArtistsTitle": "Rogue"}');
INSERT INTO public.poll_options VALUES ('c3eddbe7-c4a5-4f27-af36-689c7a4b26b7', 'Outbreak Fox Stevenson Remix - Feint feat. MYLK', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Outbreak", "Artists": [{"ID": "dd1c8f04-68fd-4f8e-a3ae-02e8e78fefc1", "URI": "feint", "Name": "Feint", "TwitterHandle": "https://twitter.com/feintMusic"}, {"ID": "9059a13b-e27e-4f5b-ae88-beb1319ebb15", "URI": "mylk", "Name": "MYLK", "TwitterHandle": "https://twitter.com/mylkofficial"}, {"ID": "07227ce4-c2e7-4763-9b52-a11bff657ee4", "URI": "foxstevenson", "Name": "Fox Stevenson", "TwitterHandle": "https://twitter.com/FoxStevensonNow"}], "TrackID": "0b86acc2-0961-4097-afe1-969456b7523c", "Version": "Fox Stevenson Remix", "CatalogID": "MCRLX001-4", "ReleaseID": "00f4dcbe-c347-4c90-97f8-95e19bae875b", "ArtistsTitle": "Feint feat. MYLK"}');
INSERT INTO public.poll_options VALUES ('0fd04f4b-d86b-4943-84ee-7dac49b52a5b', 'We Are  - Rich Edwards feat. Danyka Nadeau', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "We Are", "Artists": [{"ID": "575b43e3-7ac1-4bb2-85d7-e9ecee27bfbc", "URI": "richedwards", "Name": "Rich Edwards", "TwitterHandle": "https://twitter.com/RealRichEdwards"}, {"ID": "6b7c8c70-365b-45c2-8a44-0b4b80c40d01", "URI": "danykanadeau", "Name": "Danyka Nadeau", "TwitterHandle": "https://twitter.com/ndanyka"}], "TrackID": "4f6394e6-95dd-4577-9a28-da9b62786e4d", "Version": "", "CatalogID": "MCS330", "ReleaseID": "017c4d86-a14d-408c-9e07-d7721aef3766", "ArtistsTitle": "Rich Edwards feat. Danyka Nadeau"}');
INSERT INTO public.poll_options VALUES ('2360f034-1453-42a2-a361-8f19362cf742', 'Altara  - Johan Vilborg', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Altara", "Artists": [{"ID": "fd9ff2a7-e860-48ba-a201-234f54410d24", "URI": "johanvilborg", "Name": "Johan Vilborg", "TwitterHandle": "http://twitter.com/johanvilborg"}], "TrackID": "7f20805f-eebf-466e-985d-9ea04862dd9e", "Version": "", "CatalogID": "SILKAC10", "ReleaseID": "02b48f83-e984-4812-95af-26082373fa50", "ArtistsTitle": "Johan Vilborg"}');
INSERT INTO public.poll_options VALUES ('36ddee0a-850e-49fb-a6d4-97ddd494d3b8', 'Leaving Home  - Johan Vilborg', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Leaving Home", "Artists": [{"ID": "fd9ff2a7-e860-48ba-a201-234f54410d24", "URI": "johanvilborg", "Name": "Johan Vilborg", "TwitterHandle": "http://twitter.com/johanvilborg"}], "TrackID": "8ab1a702-1872-4e96-92c4-6c97bc81bbe7", "Version": "", "CatalogID": "SILKAC10", "ReleaseID": "02b48f83-e984-4812-95af-26082373fa50", "ArtistsTitle": "Johan Vilborg"}');
INSERT INTO public.poll_options VALUES ('12240d31-c6ea-480c-b135-67854a51acc8', 'Magellanic Clouds  - Mizar B', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Magellanic Clouds", "Artists": [{"ID": "5540daae-f000-4b20-8cb3-f78ff9bc4f7b", "URI": "mizarb", "Name": "Mizar B", "TwitterHandle": "http://twitter.com/_mizarb"}], "TrackID": "0be581ed-1f06-4af1-ad7b-77fb6c89881a", "Version": "", "CatalogID": "SILKOS03RS", "ReleaseID": "01eae2bc-f189-460f-8812-7846a2e2037c", "ArtistsTitle": "Mizar B"}');
INSERT INTO public.poll_options VALUES ('7f4a9a72-eca7-4111-b02b-338229e658f1', 'Maverick Extended Mix - Vintage & Morelli x Monoverse', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Maverick", "Artists": [{"ID": "aa338f66-69c5-4015-b2d3-cb237472df14", "URI": "vintage-morelli", "Name": "Vintage & Morelli", "TwitterHandle": "https://twitter.com/vintagemorelli"}, {"ID": "ca4ea527-cb21-4591-957f-2457b20127ca", "URI": "monoverse", "Name": "Monoverse", "TwitterHandle": "https://twitter.com/monoverse"}], "TrackID": "b8d7137f-7128-46a9-bd35-ae58b1ca6ffe", "Version": "Extended Mix", "CatalogID": "MCS1157", "ReleaseID": "006d4372-b1ed-4612-a372-1ce3d8e38f41", "ArtistsTitle": "Vintage & Morelli x Monoverse"}');
INSERT INTO public.poll_options VALUES ('0912b858-f8f5-4044-ac92-1e4b5585546f', 'Feel Alive Direct Remix - Insan3Lik3 feat. Charlotte Haining', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Feel Alive", "Artists": [{"ID": "809dc67c-205f-47a6-bf91-59b1f33b112a", "URI": "direct", "Name": "Direct", "TwitterHandle": "https://twitter.com/directofficial"}], "TrackID": "d12c2a70-2b8d-44e4-9f8d-01fde93039b2", "Version": "Direct Remix", "CatalogID": "MCF008", "ReleaseID": "00cc72a1-b973-4dc1-8cc8-63bdbb6f4974", "ArtistsTitle": "Insan3Lik3 feat. Charlotte Haining"}');
INSERT INTO public.poll_options VALUES ('bf391da4-eee8-4b1e-9e6f-37797752e72e', 'Glow Extended Mix - Shingo Nakamura', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Glow", "Artists": [{"ID": "47c6008f-910f-4b05-a65b-e193925ede9c", "URI": "shingo-nakamura", "Name": "Shingo Nakamura", "TwitterHandle": "https://twitter.com/_shingonakamura"}], "TrackID": "27987557-75c1-4cea-9c5e-a64d9346ba80", "Version": "Extended Mix", "CatalogID": "MCS1129", "ReleaseID": "01464458-d20a-4cdc-bcf1-c1459831c6a1", "ArtistsTitle": "Shingo Nakamura"}');
INSERT INTO public.poll_options VALUES ('169ec33d-0d1e-4731-87cd-dfaf52dde7d2', 'Entropy  - Mr FijiWiji & Direct', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Entropy", "Artists": [{"ID": "f8246286-de35-435a-a440-80fa2cde5c26", "URI": "mrfijiwiji", "Name": "Mr FijiWiji", "TwitterHandle": "http://twitter.com/mrfijiwiji"}, {"ID": "809dc67c-205f-47a6-bf91-59b1f33b112a", "URI": "direct", "Name": "Direct", "TwitterHandle": "https://twitter.com/directofficial"}], "TrackID": "e00d7eed-8f41-4973-b7c5-ab0bda6f0867", "Version": "", "CatalogID": "MCS252", "ReleaseID": "013499ec-6ee2-4c57-aad6-da07c86e9adf", "ArtistsTitle": "Mr FijiWiji & Direct"}');
INSERT INTO public.poll_options VALUES ('533bf838-fabc-4b1d-b8d1-37290cce86d1', 'Strong Arm  - Stephen Walking', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Strong Arm", "Artists": [{"ID": "9581f755-5b54-4876-856a-ffc4a6792b7f", "URI": "stephenwalking", "Name": "Stephen Walking", "TwitterHandle": "http://twitter.com/stephenxwalking"}], "TrackID": "25a362a6-3559-4d44-8a63-3366bdacfdc2", "Version": "", "CatalogID": "MCEP002", "ReleaseID": "0357d0cc-5480-4301-ba1c-29179a53a9d8", "ArtistsTitle": "Stephen Walking"}');
INSERT INTO public.poll_options VALUES ('b490d2ed-baf5-4b5b-a0f0-8c74f5216347', 'Maverick  - Vintage & Morelli x Monoverse', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Maverick", "Artists": [{"ID": "aa338f66-69c5-4015-b2d3-cb237472df14", "URI": "vintage-morelli", "Name": "Vintage & Morelli", "TwitterHandle": "https://twitter.com/vintagemorelli"}, {"ID": "ca4ea527-cb21-4591-957f-2457b20127ca", "URI": "monoverse", "Name": "Monoverse", "TwitterHandle": "https://twitter.com/monoverse"}], "TrackID": "9998af80-7db8-49de-bf88-bc65784a037a", "Version": "", "CatalogID": "MCS1157", "ReleaseID": "006d4372-b1ed-4612-a372-1ce3d8e38f41", "ArtistsTitle": "Vintage & Morelli x Monoverse"}');
INSERT INTO public.poll_options VALUES ('7087c1e6-fba0-4068-934f-4d7da00480af', 'Two Minds  - Kill Paris feat. Tim Moyo', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Two Minds", "Artists": [{"ID": "807cb2e7-e3d0-4f46-957b-3ad947b3f209", "URI": "killparis", "Name": "Kill Paris", "TwitterHandle": "https://twitter.com/killparis"}, {"ID": "82bb48e1-3503-425f-815b-c8716aa85625", "URI": "timmoyo", "Name": "Tim Moyo", "TwitterHandle": "https://twitter.com/moyo17"}], "TrackID": "0493d706-38b0-49fe-a95c-c3107cee7fa2", "Version": "", "CatalogID": "MCS725", "ReleaseID": "031aad70-5619-41ab-9e42-d11f84e05b2c", "ArtistsTitle": "Kill Paris feat. Tim Moyo"}');
INSERT INTO public.poll_options VALUES ('9b10948e-fd8e-48f1-b391-af9d91b4086e', 'Checkpoint  - Nitro Fun & Hyper Potions', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Checkpoint", "Artists": [{"ID": "b96670cb-5740-43b0-a9c1-e336a75996c3", "URI": "hyperpotions", "Name": "Hyper Potions", "TwitterHandle": "https://twitter.com/hyperpotions"}, {"ID": "2ab3416b-aaea-4dc7-bcb2-cefceda8b72f", "URI": "nitrofun", "Name": "Nitro Fun", "TwitterHandle": "https://twitter.com/nitrofun"}], "TrackID": "aafa7912-8b8a-40bf-888c-d5c1c6fd4065", "Version": "", "CatalogID": "MCS451", "ReleaseID": "03374765-142c-4ba8-a1e0-8a721badc83e", "ArtistsTitle": "Nitro Fun & Hyper Potions"}');
INSERT INTO public.poll_options VALUES ('774d46f0-c147-4149-ac1e-102d196d6051', 'Symphonic Change  - Johan Vilborg', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Symphonic Change", "Artists": [{"ID": "fd9ff2a7-e860-48ba-a201-234f54410d24", "URI": "johanvilborg", "Name": "Johan Vilborg", "TwitterHandle": "http://twitter.com/johanvilborg"}], "TrackID": "45d58be1-0171-43b7-b7e2-b787a8d24f3b", "Version": "", "CatalogID": "SILKAC10", "ReleaseID": "02b48f83-e984-4812-95af-26082373fa50", "ArtistsTitle": "Johan Vilborg"}');
INSERT INTO public.poll_options VALUES ('51917214-0895-4913-8b19-a8a9f0ed8c65', 'Monstercat Podcast Ep. 068  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Monstercat Podcast Ep. 068", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "cff25103-a221-4f6e-96b6-20b7f422d834", "Version": "", "CatalogID": "MCP068", "ReleaseID": "00a66830-a7fd-4e46-adc4-51b2a66334aa", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('d6a231fb-01ea-4e5a-981b-13311399ab1b', '303 - Monstercat: Call of the Wild  - Monstercat', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "303 - Monstercat: Call of the Wild", "Artists": [{"ID": "b651d573-a558-49d3-8640-363502401bcb", "URI": "monstercat", "Name": "Monstercat", "TwitterHandle": "https://twitter.com/monstercat"}], "TrackID": "13ace570-06ca-423e-98aa-946e8e5706fc", "Version": "", "CatalogID": "COTW303", "ReleaseID": "034eecf3-f40a-4605-90c8-3741be6f6004", "ArtistsTitle": "Monstercat"}');
INSERT INTO public.poll_options VALUES ('d561bb43-bfda-4506-9d49-cdafe0c42aa0', 'Warmer Days  - Johan Vilborg', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "Warmer Days", "Artists": [{"ID": "fd9ff2a7-e860-48ba-a201-234f54410d24", "URI": "johanvilborg", "Name": "Johan Vilborg", "TwitterHandle": "http://twitter.com/johanvilborg"}], "TrackID": "ed2b7bed-75a6-4c97-884c-25a75d475efb", "Version": "", "CatalogID": "SILKAC10", "ReleaseID": "02b48f83-e984-4812-95af-26082373fa50", "ArtistsTitle": "Johan Vilborg"}');
INSERT INTO public.poll_options VALUES ('58cfe1ee-dedf-460a-b6ff-a6826056497b', 'The Balance  - Nigel Good', 'a78f7cbf-5216-4a0b-8f78-6d433606f394', 0, NULL, '{"Title": "The Balance", "Artists": [{"ID": "50e2a685-3b08-4e32-99b7-b5b9ac2817e0", "URI": "nigelgood", "Name": "Nigel Good", "TwitterHandle": "https://twitter.com/nigelgood"}], "TrackID": "00fbeaf0-c87d-4e37-aa06-77cbd4a6e588", "Version": "", "CatalogID": "SILK064", "ReleaseID": "00d2bf73-e544-4510-92a5-c0e69a5042bc", "ArtistsTitle": "Nigel Good"}');


--
-- Data for Name: poll_votes; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.poll_votes VALUES ('2af97b85-b39f-46d8-af4e-0743c25c1831', 'a64b89e5-ed32-424e-9a0a-612290814eb2', '6075c7db-76e3-4b6b-a1b0-96cd1c41bc3c', '10.12.14.15', 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-en) AppleWebKit/533.19.4 (KHTML, like Gecko) Version/5.0.3 Safari/533.19.4', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('57b40568-0962-48eb-b783-5de89a67eda1', '99315a02-c984-4dc4-92c4-68ed29907850', 'c89cf076-b4f4-4b11-a57a-bb84baac157f', '123.43.12.53', 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-en) AppleWebKit/533.19.4 (KHTML, like Gecko) Version/5.0.3 Safari/533.19.4', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('a82f6935-8249-41ac-8198-b91062e49a5c', '9f0c3fa4-f3d4-4203-816c-09c77035f238', 'c89cf076-b4f4-4b11-a57a-bb84baac157f', '210.12.14.210', 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_6; en-en) AppleWebKit/533.19.4 (KHTML, like Gecko) Version/5.0.3 Safari/533.19.4', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('74a6f205-7f6a-487d-9c18-97fec6793982', '50f4acd7-a2f7-49a6-aac0-18a53cb0b419', '6075c7db-76e3-4b6b-a1b0-96cd1c41bc3c', '', '', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('841123e5-29e1-4a62-a29b-34b4eeae94bd', '1a665b8b-b167-4230-b4f1-ab19d24e1588', '6075c7db-76e3-4b6b-a1b0-96cd1c41bc3c', '', 'IPhone/Android', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('c9de43fe-e8aa-488b-aca8-9cc4325792e7', '1a665b8b-b167-4230-b4f1-ab19d24e1588', '1f602f55-44e1-45c7-affc-6db7ba8d7042', '', '', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('95126ee5-2bac-4ae9-a068-35237a1ac233', 'a64b89e5-ed32-424e-9a0a-612290814eb2', 'c89cf076-b4f4-4b11-a57a-bb84baac157f', '120.12.14.56', 'A Bot', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('c4338c76-9543-45d9-8216-9792bff83d1e', '7a7db510-7968-45e6-81fc-75fd46b5d8ef', 'ec0c9e58-ea33-4a44-9415-78f748fe6b2d', '122.32.53.112', 'Mozilla/Bot', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('550c6aa9-e37f-4943-b279-db5a54bdd332', '8537aba7-4dd3-4708-ae08-7f51a6d61b2e', 'ec0c9e58-ea33-4a44-9415-78f748fe6b2d', '122.32.53.112', 'Mozilla/Bot', '2021-04-20 22:42:46.867767-07');
INSERT INTO public.poll_votes VALUES ('2f17c439-1344-43e1-85ea-bcb999b17412', 'b25abe62-c654-4f11-81f2-eeb8d599818f', 'ec0c9e58-ea33-4a44-9415-78f748fe6b2d', '122.32.53.112', 'Mozilla/Bot', '2021-04-20 22:42:46.867767-07');


--
-- Data for Name: polls; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.polls VALUES ('94e0ed6f-04f4-4af8-a621-f580113512a0', false, 'mixcontest2016', 'Who should win week 1?', '2017-04-20 22:42:46.867767-07', '2018-04-20 22:42:46.867767-07', 'America/Vancouver', 1, 2, '2021-04-20 22:42:46.867767-07', '2021-04-20 22:42:46.867767-07', 0, false);
INSERT INTO public.polls VALUES ('0c4509eb-3065-453b-8b36-cd6189990842', false, 'mixcontest2019', 'Who should win week 1?', '2021-04-06 22:42:46.867767-07', '2021-04-13 22:42:46.867767-07', 'America/Vancouver', 1, 2, '2021-04-20 22:42:46.867767-07', '2021-04-20 22:42:46.867767-07', 0, false);
INSERT INTO public.polls VALUES ('a78f7cbf-5216-4a0b-8f78-6d433606f394', false, 'mixcontest2019', 'Who should win week 2?', '2021-04-19 22:42:46.867767-07', '2021-04-26 22:42:46.867767-07', 'America/Vancouver', 1, 2, '2021-04-20 22:42:46.867767-07', '2021-04-20 22:42:46.867767-07', 0, false);
INSERT INTO public.polls VALUES ('fc5ef74c-107e-48ad-9ab5-d6f4efcc8686', true, 'mixcontest2019', 'Deleted Poll', '2021-04-18 22:42:46.867767-07', '2021-04-26 22:42:46.867767-07', 'America/Vancouver', 1, 2, '2021-04-20 22:42:46.867767-07', '2021-04-20 22:42:46.867767-07', 0, false);
INSERT INTO public.polls VALUES ('3217c48d-0bfb-4ff8-ae9e-ba3c074774ba', false, 'mixcontest2019', 'Who should win the whole thing?', '2021-04-29 22:42:46.867767-07', '2021-05-05 22:42:46.867767-07', 'America/Vancouver', 1, 1, '2021-04-20 22:42:46.867767-07', '2021-04-20 22:42:46.867767-07', 0, false);


--
-- Data for Name: shop_codes; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: social_access_tokens; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: streamlabs_payments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: streamlabs_profiles; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: streamlabs_subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: territories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.territories VALUES ('544e0cea-5e46-4098-8f6a-b5a0a767ee8c', 'Canada');
INSERT INTO public.territories VALUES ('a47a9169-d075-446c-8a19-1955ca1548d2', 'Peru');
INSERT INTO public.territories VALUES ('9eae7849-cf6c-45af-a0cd-2324f4ce3ef5', 'Brisbane');
INSERT INTO public.territories VALUES ('b533b357-67ff-452c-b706-9e9c2ac57093', 'Thailand');
INSERT INTO public.territories VALUES ('c0f40581-3d77-4b27-a013-90205ef5954f', 'Germany');
INSERT INTO public.territories VALUES ('a977fcf2-a1b4-4168-b9d1-6801e46da156', 'UK');
INSERT INTO public.territories VALUES ('48d5dc4a-d238-4e05-87a4-3e61fce84eb0', 'Poland');
INSERT INTO public.territories VALUES ('90af41ba-3fdf-4eb1-aff4-080a0b717b7e', 'North America');
INSERT INTO public.territories VALUES ('b96abdf1-efeb-4e31-9e67-0125889d6256', 'Japan');
INSERT INTO public.territories VALUES ('2460aaf3-8a2b-4a3a-acff-23377ecb93da', 'Switzerland');
INSERT INTO public.territories VALUES ('be141d5e-d0a2-4e4e-ae17-eae4e91309ec', 'Russia');
INSERT INTO public.territories VALUES ('de988578-8161-451b-83bb-2e5dc17d8493', 'Costa Rica');
INSERT INTO public.territories VALUES ('a06df5ae-21bf-471c-b85a-1cd090dea53d', 'Dubai');
INSERT INTO public.territories VALUES ('38fe387c-07a6-4230-8c6d-761816071d46', 'Netherlands');
INSERT INTO public.territories VALUES ('1de1833c-d161-4bc2-a197-86f2c9a627ee', 'Hawaii');
INSERT INTO public.territories VALUES ('86b416cf-157b-4d48-a6d2-61a2dd805f87', 'Colombia');
INSERT INTO public.territories VALUES ('0887d2af-fa29-4afd-94da-30d88f4eb3f2', 'China');
INSERT INTO public.territories VALUES ('cd80238d-a1e2-48b8-97b6-7c00b46a3b2e', 'Worldwide');
INSERT INTO public.territories VALUES ('85bc4ec8-c65e-49aa-8762-978118c64df7', 'Belgium');
INSERT INTO public.territories VALUES ('b36bc5cf-77d8-490c-928e-91561eab9ca8', 'France');
INSERT INTO public.territories VALUES ('053d155a-cb9f-4ed1-84a4-2a44fccedb01', 'Middle East / North Africa');
INSERT INTO public.territories VALUES ('c453d9e0-27da-49d0-9e4b-b72ee69d6fc1', 'USA');


--
-- Data for Name: user_features; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'cache.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'licenses.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'playlists.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'podcasts.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'polls.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'menus.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'moods.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'users.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'xsolla.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'features.manage');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'full-catalog.view');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'invite.resend');
INSERT INTO public.user_features VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', 'gold-stats.view');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'cache.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'licenses.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'playlists.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'podcasts.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'polls.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'menus.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'moods.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'users.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'xsolla.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'features.manage');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'full-catalog.view');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'invite.resend');
INSERT INTO public.user_features VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', 'gold-stats.view');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'cache.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'licenses.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'playlists.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'podcasts.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'polls.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'menus.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'moods.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'users.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'xsolla.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'features.manage');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'full-catalog.view');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'invite.resend');
INSERT INTO public.user_features VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', 'gold-stats.view');


--
-- Data for Name: user_settings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.user_settings VALUES ('d4987964-0163-4263-90d2-4bd218b06fd9', false, false, false, '', true, 'a64b89e5-ed32-424e-9a0a-612290814eb2');
INSERT INTO public.user_settings VALUES ('6f9ce3ea-934a-4896-888c-7f015630e10b', true, true, false, '', true, '459d701b-9b2f-4089-883c-e3eb7a6d1a75');


--
-- Data for Name: user_stats; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.users VALUES ('e4a3c750-c82e-44c6-9c1a-a131036cecdd', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'Testing@monstercat.com', '', 'unverified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$Ic2sP7ZFwTjqNBeuBvAaQeNuqwUOayYIgZS5D8ft65iJCWxTglBZ.', '99e6adbe046347edb2a9a8538398919c', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'Bahrun Amik Bila Sahil', 'e4a3c750-c82e-44c6-9c1a-a131036cecdd', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('b9f36c54-02e6-4082-9ee7-a80474a8afa4', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'SycNasty@monstercat.com', '', 'verified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$cMgJm6D6VTWEtuUuf/VJtO0mWNkzEt/sPLc/bBTUVp5Dkbcna82y2', '8af89c710bd6404fadfe761350564ef9', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', '', 'b9f36c54-02e6-4082-9ee7-a80474a8afa4', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('d47784de-03e8-4c69-81e5-4b02931082e8', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'gold-benefits-on@gmail.com', '', 'unverified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$RDZMe8sNIqS11RmHEN6dz.JSn8U13EIr0dkmjmmdZcg.KHjPd3tZq', '74ab0f7809664518a7eb4430ec72eaf5', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', '', 'd47784de-03e8-4c69-81e5-4b02931082e8', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('cb81745f-ba7b-4f53-aafb-efe0b2a71e74', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'braydanek@monstercat.com', '', 'unverified', 'Braydan', false, '', '', false, 'Kenny', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'Braydan Kenny', 'cb81745f-ba7b-4f53-aafb-efe0b2a71e74', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('b07a0363-7779-46c3-b260-459e0c23c483', false, '{}', '0001-01-01', 'Erie', 'North America', 'United States of America', '2020-01-29 04:38:27.790186-08', 'andrewhall096@monstercat.com', '', 'unverified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', -80.085059, 42.12922409999999, 0, NULL, '$2a$08$2X715vuiOpGHiesoxtGqFumLt5zbGC9Ipjs/4SP9CDlj60H4aeKl2', 'cc6310e492394bb48b90ed0248e1266f', 'Erie', 'Erie, PA, USA', '', 'PA', 'Pennsylvania', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', '', 'b07a0363-7779-46c3-b260-459e0c23c483', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('edbe2f96-5549-4cdd-97b7-2f2e3b11415b', false, '{}', '0001-01-01', 'Prague', 'Europe', 'Czechia', '2020-01-29 04:38:27.790186-08', 'beckkamil@monstercat.com', '', 'unverified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', 14.4378005, 50.0755381, 0, NULL, '$2a$08$Cau9BGsunY0fsigpNw9eOOMPksw6gS9UniQsfEnMeUwFFKR0DvvoO', '6c19eaa2a2af45e2bab6e2a4608bb9c5', 'Prague', 'Prague, Czechia', '', 'Prague', 'Prague', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', '', 'edbe2f96-5549-4cdd-97b7-2f2e3b11415b', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('1df819ef-074c-40b3-99b2-8992e59edd7d', false, '{}', '0001-01-01', 'Staunton', 'North America', 'United States of America', '2020-01-29 04:38:27.790186-08', 'vxture@gmail.com', '', 'unverified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', -79.0716958, 38.149576, 0, NULL, '$2a$08$kMCiUh/bRg3eGPcq3FeU7.u.p5cLxFecfH5h5x4naDlDe1IMnZMOi', '', 'Staunton', 'Staunton, VA 24401, USA', '', 'VA', 'Virginia', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', '', '1df819ef-074c-40b3-99b2-8992e59edd7d', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('961bc180-a269-495e-bc48-76ae9052d5c0', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'unittestingfakeuser@monstercat.com', '', 'unverified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$JHs4qdMGmRjjWFkIhQixD.ZiE.VabIHYcMyxA.n3XPTxMZXtf44WG', '74ab0f7809664518a7eb4430ec72eaf5', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', '', '961bc180-a269-495e-bc48-76ae9052d5c0', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('d36a7e34-027b-4340-a9dd-3e9cb98d4675', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'peterbp2003@monstercat.com', '', 'unverified', 'Peter', false, '', '', false, 'Porcaro', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$YEvHagmbShVGYZpChx2IV.tkcOYv1HT/4nYrEMYbFAivow8aHOxaC', '', '', '', '', '', '', '', NULL, '16585906', '', '2020-01-29 04:38:27.790186-08', 'Peter Porcaro', 'd36a7e34-027b-4340-a9dd-3e9cb98d4675', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('d9bd9732-76bf-43f8-b2e8-a41bc24b66d7', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'haha-ralf@monstercat.com', '', 'unverified', '', false, '', '', false, '', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$5ntthwt8I6GjQqnIfxMJLenUBGBwiluBQNY5IuGmo2x.TRE7N.JxW', '8edeab93c57e48989845336ad3a233b6', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', '', 'd9bd9732-76bf-43f8-b2e8-a41bc24b66d7', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('be17c849-af60-4888-92aa-60461042501b', true, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'deleted-user@monstercat.com', '', 'unverified', 'Testy', false, '', '', false, 'McTestington', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$JHs4qdMGmRjjWFkIhQixD.ZiE.VabIHYcMyxA.n3XPTxMZXtf44WG', '', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'test', 'be17c849-af60-4888-92aa-60461042501b', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('2208cad5-cab3-4352-84cd-ba3f34f04f6f', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'test+102@monstercat.com', '', 'unverified', 'Testy', false, '', '', false, 'McTestington', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$JHs4qdMGmRjjWFkIhQixD.ZiE.VabIHYcMyxA.n3XPTxMZXtf44WG', '', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'test', '2208cad5-cab3-4352-84cd-ba3f34f04f6f', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('c5f44b6c-592a-4752-9c90-1407856b8e4d', false, '{}', '0001-01-01', 'Toronto', 'North America', 'Canada', '2020-01-29 04:38:27.790186-08', 'ephemeraleclipse@monstercat.com', '', 'unverified', 'Ling', false, '', '', false, 'Xing', '0001-01-01 08:12:28-08:12:28', -79.3831843, 43.653226, 0, NULL, '$2a$08$JHs4qdMGmRjjWFkIhQixD.ZiE.VabIHYcMyxA.n3XPTxMZXtf44WG', 'e883472d2bf54260abda162a2d05b070', 'Toronto', 'Toronto, ON, Canada', '', 'ON', 'Ontario', '', NULL, '23857727', '', '2020-01-29 04:38:27.790186-08', 'Ling Xing', 'c5f44b6c-592a-4752-9c90-1407856b8e4d', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('c1263a41-7176-4ae1-a0a8-60d6474d2f77', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+xsollasub@monstercat.com', '', 'unverified', 'Xsolla', false, '', '', false, 'Subber', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Xsolla Subber', '5c81946dc0aea683433182a3', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('b25c1942-f97c-4172-af0b-fb4b8241b39a', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+xsollasubcanceled@monstercat.com', '', 'unverified', 'Xsolla Subber', false, '', '', false, 'To Be Canceled', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Xsolla Subber To Be Canceled', 'b25c1942-f97c-4172-af0b-fb4b8241b39a', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('b94039e9-73a1-487a-b069-31c501e89e05', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+testadmin@monstercat.com', '', 'unverified', 'Admin', false, '', '', false, 'User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Admin User', 'b94039e9-73a1-487a-b069-31c501e89e05', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('1a665b8b-b167-4230-b4f1-ab19d24e1588', false, '{"news": true}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'test+klaviyo@monstercat.com', '', 'unverified', 'Testy', false, '', 'PMjCy8', false, 'Emailer', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$JHs4qdMGmRjjWFkIhQixD.ZiE.VabIHYcMyxA.n3XPTxMZXtf44WG', '', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'test', '1a665b8b-b167-4230-b4f1-ab19d24e1588', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('7a7db510-7968-45e6-81fc-75fd46b5d8ef', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+xsollacreated@monstercat.com', '', 'unverified', 'User', false, '', '', false, 'Add Xsolla Sub', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'User Add Xsolla Sub', '7a7db510-7968-45e6-81fc-75fd46b5d8ef', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('064c4ae2-81cd-49dc-ae38-bc7cd121f54e', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+publicplaylistuser@monstercat.com', '', 'unverified', 'Public', false, '', '', false, 'Playlist User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Public Playlist User', '064c4ae2-81cd-49dc-ae38-bc7cd121f54e', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('38b5ba88-5a26-46de-81f6-fc4d4d361bb5', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+artistplaylistuser@monstercat.com', '', 'unverified', 'Artist', false, '', '', false, 'Playlist User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Artist Playlist User', '38b5ba88-5a26-46de-81f6-fc4d4d361bb5', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('5b19d40a-035d-464c-be9a-283a791f1d80', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+testsocials@monstercat.com', '', 'unverified', 'Socials', false, '', '', false, 'User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Socials User', '5b19d40a-035d-464c-be9a-283a791f1d80', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('99315a02-c984-4dc4-92c4-68ed29907850', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+testexistingpaypalsub@monstercat.com', '', 'unverified', 'Existing', false, '', '', false, 'Paypal Sub User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Existing Paypal Sub User', '99315a02-c984-4dc4-92c4-68ed29907850', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('9f0c3fa4-f3d4-4203-816c-09c77035f238', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+testnewpaypalsub@monstercat.com', '', 'unverified', 'New Paypal', false, '', '', false, 'Sub User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'New Paypal Sub User', '9f0c3fa4-f3d4-4203-816c-09c77035f238', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('50f4acd7-a2f7-49a6-aac0-18a53cb0b419', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+licenseeee@monstercat.com', '', 'unverified', 'Static', false, '', '', false, 'Licensee User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Licensee User', '50f4acd7-a2f7-49a6-aac0-18a53cb0b419', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('cddccf15-dcc4-4c03-8121-68c8e31d18cd', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+teststreamlabslegacy@monstercat.com', '', 'unverified', 'Legacy', false, '', '', false, 'Streamlabs User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Legacy Streamlabs User', 'cddccf15-dcc4-4c03-8121-68c8e31d18cd', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('e1126e97-a087-4cdd-8739-8cd898c065a7', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+teststreamlabsprime@monstercat.com', '', 'unverified', 'Prime', false, '', '', false, 'Streamlabs User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Prime Streamlabs User', 'e1126e97-a087-4cdd-8739-8cd898c065a7', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('a53267a7-6277-47ea-be46-6b5ec07f993d', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+freegold@monstercat.com', '', 'unverified', 'Free', false, '', '', false, 'Gold User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'hasfreegold', 'a53267a7-6277-47ea-be46-6b5ec07f993d', true, '', NULL, NULL);
INSERT INTO public.users VALUES ('30a3fbc7-1db1-4659-ac0d-e54ce5855c3a', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'testing+expireduser@monstercat.com', '', 'unverified', 'Expired', false, '', '', false, 'User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'Expired User', '30a3fbc7-1db1-4659-ac0d-e54ce5855c3a', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('672bad80-5b86-45ba-88db-4552b8e14c47', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+twofactorenabled@monstercat.com', '', 'unverified', 'Two', false, '', '', false, 'Factor Enabled User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$RrSR5KAOWeRRl08DWE7QVenAdcMKqn9JF0yah13c6ZnFAoezYe3H2', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '333444555', '', '2020-01-30 05:26:30.017348-08', 'two_factor_enabled', '672bad80-5b86-45ba-88db-4552b8e14c47', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('f0d42142-5690-4b75-a7d7-0a6c4e503618', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+searchableuser1@monstercat.com', '', 'unverified', 'Ludwig', false, '', '', false, 'Van Bethoven', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'lbeethoven', 'f0d42142-5690-4b75-a7d7-0a6c4e503618', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('85b17bf3-7738-44c4-86ea-95582524dea0', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+searchableuser2@monstercat.com', '', 'unverified', 'Leopold', false, '', '', false, 'Mozart', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'leomozart', '85b17bf3-7738-44c4-86ea-95582524dea0', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('84d6a1b1-092d-493f-8066-3be8dba03fcb', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+searchableuser3@monstercat.com', '', 'unverified', 'Wolfgang', false, '', '', false, 'Mozart', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'cooldude1', '84d6a1b1-092d-493f-8066-3be8dba03fcb', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('a72bf5ed-9ad3-4ad1-bc86-5db72395f6ae', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+anotherplaylistuser@monstercat.com', '', 'unverified', 'Another', false, '', '', false, 'Playlist User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'Another Playlist User', 'a72bf5ed-9ad3-4ad1-bc86-5db72395f6ae', false, '', NULL, 'ecccd368-0fe5-4b44-abdc-e5796efe3418');
INSERT INTO public.users VALUES ('b25abe62-c654-4f11-81f2-eeb8d599818f', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+slfreemium@monstercat.com', '', 'unverified', 'Wolfgang', false, '', '', false, 'Mozart', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$EIBwCio8FT.EKDR7NlQKN.iMPhs1ndVOPzycRPtB50JHQIR1Amrw.', '68f9f7c95f844f0fb9cad2908ed97ea9', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', 'streamlabs', 'b25abe62-c654-4f11-81f2-eeb8d599818f', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('e5ca514a-7415-4d2b-85dd-dd985cc29e01', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+lastseenuser@monstercat.com', '', 'unverified', 'Last', false, '', '', false, 'Seen User', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$RrSR5KAOWeRRl08DWE7QVenAdcMKqn9JF0yah13c6ZnFAoezYe3H2', '', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', '', 'e5ca514a-7415-4d2b-85dd-dd985cc29e01', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('45ac2da6-0654-447f-8fef-c018c031f00e', false, '{}', '0001-01-01', '', '', '', '2020-01-30 05:26:30.017348-08', 'testing+lastseenuser2@monstercat.com', '', 'unverified', 'Last', false, '', '', false, 'Seen User II', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$RrSR5KAOWeRRl08DWE7QVenAdcMKqn9JF0yah13c6ZnFAoezYe3H2', '', '', '', '', '', '', '', NULL, '', '', '2020-01-30 05:26:30.017348-08', '', '45ac2da6-0654-447f-8fef-c018c031f00e', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('8537aba7-4dd3-4708-ae08-7f51a6d61b2e', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'test+givendownloadaccess@monstercat.com', '', 'unverified', 'Testy', true, '', '', false, 'McTestington', '0001-01-01 08:12:28-08:12:28', NULL, NULL, 0, NULL, '$2a$08$JHs4qdMGmRjjWFkIhQixD.ZiE.VabIHYcMyxA.n3XPTxMZXtf44WG', '', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'test', '8537aba7-4dd3-4708-ae08-7f51a6d61b2e', false, '', NULL, NULL);
INSERT INTO public.users VALUES ('459d701b-9b2f-4089-883c-e3eb7a6d1a75', false, '{}', '0001-01-01', '', '', '', '2021-04-21 22:01:52.727236-07', 'dev@monstercat.com', '', 'pending', 'dev', false, '', '', false, 'tester', '0001-01-01 00:00:00-08:12:28', NULL, NULL, 0, NULL, '', '', '', '', '', '', '', '', NULL, '', '', '0001-01-01 00:00:00-08:12:28', '', '459d701b-9b2f-4089-883c-e3eb7a6d1a75', true, '', '2021-04-21 22:05:46.642659-07', NULL);
INSERT INTO public.users VALUES ('a64b89e5-ed32-424e-9a0a-612290814eb2', false, '{}', '0001-01-01', '', '', '', '2020-01-29 04:38:27.790186-08', 'test@monstercat.com', '', 'unverified', 'Testy', false, '', '', false, 'McTestington', '2021-11-17 11:28:55.813842-08', NULL, NULL, 0, NULL, '$2a$08$JHs4qdMGmRjjWFkIhQixD.ZiE.VabIHYcMyxA.n3XPTxMZXtf44WG', '', '', '', '', '', '', '', NULL, '', '', '2020-01-29 04:38:27.790186-08', 'test', 'a64b89e5-ed32-424e-9a0a-612290814eb2', true, '', '2021-04-21 19:57:31.769859-07', '1b605130-c810-4f50-a6b2-3305f669d88a');


--
-- Data for Name: webhook_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: xsolla_payments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: xsolla_subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.xsolla_subscriptions VALUES ('ee726c92-8767-4211-92ab-1bdf7ffc2c00', false, '2020-03-03 00:33:02.211948-08', '2020-03-03 00:33:02.211948-08', 'plan_123', '28866378', 'Active', 'c1263a41-7176-4ae1-a0a8-60d6474d2f77');
INSERT INTO public.xsolla_subscriptions VALUES ('aa97cb38-8748-4184-8b54-08ed0b774f54', false, '2020-03-03 00:33:02.211948-08', '2020-03-03 00:33:02.211948-08', 'plan_123', '22222222', 'Active', 'b25c1942-f97c-4172-af0b-fb4b8241b39a');
INSERT INTO public.xsolla_subscriptions VALUES ('e254be9a-869c-4b8d-ba07-9533a738d59d', false, '2020-03-03 00:33:02.211948-08', '2020-03-03 00:33:02.211948-08', 'plan_123', 'sub_123', 'Active', 'b94039e9-73a1-487a-b069-31c501e89e05');


--
-- Data for Name: youtube_stats; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Name: gold_stats_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.gold_stats_id_seq', 1, false);


--
-- Name: http_sessions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.http_sessions_id_seq', 9, true);


--
-- Name: webhook_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.webhook_logs_id_seq', 1, false);


--
-- Name: article_artists article_artist_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_artists
    ADD CONSTRAINT article_artist_uniq PRIMARY KEY (article_id, artist_id);


--
-- Name: article_categories article_category_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_categories
    ADD CONSTRAINT article_category_uniq PRIMARY KEY (article_id, category_id);


--
-- Name: article_releases article_release_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_releases
    ADD CONSTRAINT article_release_uniq PRIMARY KEY (article_id, release_id);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: articles articles_vanity_uri_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_vanity_uri_key UNIQUE (vanity_uri);


--
-- Name: careers_links careers_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.careers_links
    ADD CONSTRAINT careers_links_pkey PRIMARY KEY (id);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: featured_artists featured_artists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.featured_artists
    ADD CONSTRAINT featured_artists_pkey PRIMARY KEY (id);


--
-- Name: file_status file_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_status
    ADD CONSTRAINT file_status_pkey PRIMARY KEY (id);


--
-- Name: files files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.files
    ADD CONSTRAINT files_pkey PRIMARY KEY (id);


--
-- Name: gold_time_ranges gold_time_ranges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gold_time_ranges
    ADD CONSTRAINT gold_time_ranges_pkey PRIMARY KEY (id);


--
-- Name: gold_unsub_survey_results gold_unsub_survey_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gold_unsub_survey_results
    ADD CONSTRAINT gold_unsub_survey_results_pkey PRIMARY KEY (id);


--
-- Name: homepage_slider_item homepage_slider_item_id_slider_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider_item
    ADD CONSTRAINT homepage_slider_item_id_slider_type_key UNIQUE (id, slider_type);


--
-- Name: homepage_slider_item homepage_slider_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider_item
    ADD CONSTRAINT homepage_slider_item_pkey PRIMARY KEY (id);


--
-- Name: homepage_slider homepage_slider_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider
    ADD CONSTRAINT homepage_slider_pkey PRIMARY KEY (id);


--
-- Name: http_sessions http_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.http_sessions
    ADD CONSTRAINT http_sessions_pkey PRIMARY KEY (id);


--
-- Name: license_access_tokens license_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_access_tokens
    ADD CONSTRAINT license_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: license_time_ranges license_time_ranges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_time_ranges
    ADD CONSTRAINT license_time_ranges_pkey PRIMARY KEY (id);


--
-- Name: licenses licenses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.licenses
    ADD CONSTRAINT licenses_pkey PRIMARY KEY (id);


--
-- Name: menus menu_code_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menus
    ADD CONSTRAINT menu_code_uniq UNIQUE (code);


--
-- Name: menu_items menu_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_pkey PRIMARY KEY (id);


--
-- Name: menu_sections menu_sections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_sections
    ADD CONSTRAINT menu_sections_pkey PRIMARY KEY (id);


--
-- Name: menus menus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menus
    ADD CONSTRAINT menus_pkey PRIMARY KEY (id);


--
-- Name: mood_omitted_songs mood_omitted_songs_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mood_omitted_songs
    ADD CONSTRAINT mood_omitted_songs_uniq PRIMARY KEY (mood_id, track_id, release_id);


--
-- Name: mood_params mood_param_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mood_params
    ADD CONSTRAINT mood_param_uniq PRIMARY KEY (mood_id, param);


--
-- Name: moods mood_uri_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moods
    ADD CONSTRAINT mood_uri_uniq UNIQUE (uri);


--
-- Name: moods moods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moods
    ADD CONSTRAINT moods_pkey PRIMARY KEY (id);


--
-- Name: page_counter page_counter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.page_counter
    ADD CONSTRAINT page_counter_pkey PRIMARY KEY (page);


--
-- Name: paypal_payments paypal_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paypal_payments
    ADD CONSTRAINT paypal_payments_pkey PRIMARY KEY (id);


--
-- Name: paypal_subscriptions paypal_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paypal_subscriptions
    ADD CONSTRAINT paypal_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: playlists playlists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlists
    ADD CONSTRAINT playlists_pkey PRIMARY KEY (id);


--
-- Name: podcast_stations podcast_stations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.podcast_stations
    ADD CONSTRAINT podcast_stations_pkey PRIMARY KEY (id);


--
-- Name: podcasts podcasts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.podcasts
    ADD CONSTRAINT podcasts_pkey PRIMARY KEY (id);


--
-- Name: podcasts podcasts_uri_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.podcasts
    ADD CONSTRAINT podcasts_uri_key UNIQUE (uri);


--
-- Name: poll_options poll_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT poll_options_pkey PRIMARY KEY (id);


--
-- Name: poll_votes poll_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_pkey PRIMARY KEY (id);


--
-- Name: polls polls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT polls_pkey PRIMARY KEY (id);


--
-- Name: shop_codes shop_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_codes
    ADD CONSTRAINT shop_codes_pkey PRIMARY KEY (id);


--
-- Name: social_access_tokens social_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_access_tokens
    ADD CONSTRAINT social_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: streamlabs_payments streamlabs_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streamlabs_payments
    ADD CONSTRAINT streamlabs_payments_pkey PRIMARY KEY (id);


--
-- Name: streamlabs_profiles streamlabs_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streamlabs_profiles
    ADD CONSTRAINT streamlabs_profiles_pkey PRIMARY KEY (id);


--
-- Name: streamlabs_subscriptions streamlabs_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streamlabs_subscriptions
    ADD CONSTRAINT streamlabs_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: territories territories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.territories
    ADD CONSTRAINT territories_pkey PRIMARY KEY (id);


--
-- Name: user_features user_features_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_features
    ADD CONSTRAINT user_features_unique PRIMARY KEY (user_id, feature);


--
-- Name: user_settings user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_pkey PRIMARY KEY (id);


--
-- Name: user_stats user_stats_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stats
    ADD CONSTRAINT user_stats_user_id_key UNIQUE (user_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webhook_logs webhook_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_logs
    ADD CONSTRAINT webhook_logs_pkey PRIMARY KEY (id);


--
-- Name: xsolla_payments xsolla_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xsolla_payments
    ADD CONSTRAINT xsolla_payments_pkey PRIMARY KEY (id);


--
-- Name: xsolla_subscriptions xsolla_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xsolla_subscriptions
    ADD CONSTRAINT xsolla_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: youtube_stats youtube_stats_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.youtube_stats
    ADD CONSTRAINT youtube_stats_uniq PRIMARY KEY (channel_id);


--
-- Name: analytic_events_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytic_events_created_at_idx ON public.analytic_events USING btree (created_at);


--
-- Name: analytic_events_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytic_events_name_idx ON public.analytic_events USING btree (name);


--
-- Name: analytic_events_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX analytic_events_user_id_idx ON public.analytic_events USING btree (user_id);


--
-- Name: featured_digital_events_sort_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX featured_digital_events_sort_idx ON public.featured_digital_events USING btree (sort);


--
-- Name: featured_live_events_sort_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX featured_live_events_sort_idx ON public.featured_live_events USING btree (sort);


--
-- Name: featured_releases_sort_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX featured_releases_sort_idx ON public.featured_releases USING btree (sort);


--
-- Name: gold_time_ranges_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gold_time_ranges_created_at_idx ON public.gold_time_ranges USING btree (created_at);


--
-- Name: gold_time_ranges_finish_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gold_time_ranges_finish_idx ON public.gold_time_ranges USING btree (finish);


--
-- Name: gold_time_ranges_start_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gold_time_ranges_start_idx ON public.gold_time_ranges USING btree (start);


--
-- Name: gold_time_ranges_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX gold_time_ranges_user_id_idx ON public.gold_time_ranges USING btree (user_id);


--
-- Name: homepage_slider_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX homepage_slider_active ON public.homepage_slider USING btree (active) WHERE active;


--
-- Name: http_sessions_substr_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX http_sessions_substr_idx ON public.http_sessions USING btree (substr(key, 1, 6));


--
-- Name: license_time_ranges_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX license_time_ranges_created_at_idx ON public.license_time_ranges USING btree (created_at);


--
-- Name: license_time_ranges_finish_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX license_time_ranges_finish_idx ON public.license_time_ranges USING btree (finish);


--
-- Name: license_time_ranges_gold_time_range_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX license_time_ranges_gold_time_range_id_idx ON public.license_time_ranges USING btree (gold_time_range_id);


--
-- Name: license_time_ranges_license_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX license_time_ranges_license_id_idx ON public.license_time_ranges USING btree (license_id);


--
-- Name: license_time_ranges_start_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX license_time_ranges_start_idx ON public.license_time_ranges USING btree (start);


--
-- Name: licenses_adhoc_apply_syncable_query; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX licenses_adhoc_apply_syncable_query ON public.licenses USING btree (((state <> 'Banned'::public.license_state))) WHERE ((archived = false) AND (vendor = 'YouTube'::public.license_vendor) AND (whitelisted IS DISTINCT FROM (state <> 'Banned'::public.license_state)));


--
-- Name: INDEX licenses_adhoc_apply_syncable_query; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON INDEX public.licenses_adhoc_apply_syncable_query IS 'This is an adhoc index for the ApplySyncableQuery.';


--
-- Name: licenses_identity_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX licenses_identity_idx ON public.licenses USING btree (identity);


--
-- Name: licenses_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX licenses_user_id_idx ON public.licenses USING btree (user_id);


--
-- Name: menu_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_code ON public.menus USING btree (code);


--
-- Name: paypal_subscriptions_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX paypal_subscriptions_user_id_idx ON public.paypal_subscriptions USING btree (user_id);


--
-- Name: playlist_items_sort_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX playlist_items_sort_index ON public.playlist_items USING btree (playlist_id, sort);


--
-- Name: playlists_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX playlists_user_id_idx ON public.playlists USING btree (user_id);


--
-- Name: podcast_stations_podcast_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX podcast_stations_podcast_id ON public.podcast_stations USING btree (podcast_id);


--
-- Name: podcast_stations_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX podcast_stations_sort_order ON public.podcast_stations USING btree (sort_order);


--
-- Name: podcast_stations_territory_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX podcast_stations_territory_id ON public.podcast_stations USING btree (territory_id);


--
-- Name: podcasts_uri; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX podcasts_uri ON public.podcasts USING btree (uri);


--
-- Name: poll_options_poll_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX poll_options_poll_id ON public.poll_options USING btree (poll_id);


--
-- Name: poll_options_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX poll_options_sort ON public.poll_options USING btree (sort);


--
-- Name: poll_votes_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX poll_votes_user_id ON public.poll_votes USING btree (user_id);


--
-- Name: poll_votes_vote_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX poll_votes_vote_time ON public.poll_votes USING btree (vote_time);


--
-- Name: shop_codes_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shop_codes_user_id_idx ON public.shop_codes USING btree (user_id);


--
-- Name: social_access_token_uniq; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX social_access_token_uniq ON public.social_access_tokens USING btree (user_id, platform) WHERE (user_id IS NOT NULL);


--
-- Name: streamlabs_profiles_streamlabs_uid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX streamlabs_profiles_streamlabs_uid_idx ON public.streamlabs_profiles USING btree (streamlabs_uid);


--
-- Name: streamlabs_profiles_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX streamlabs_profiles_user_id_idx ON public.streamlabs_profiles USING btree (user_id);


--
-- Name: streamlabs_subscriptions_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX streamlabs_subscriptions_user_id_idx ON public.streamlabs_subscriptions USING btree (user_id);


--
-- Name: user_settings_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_settings_user_id_idx ON public.user_settings USING btree (user_id);


--
-- Name: users_archived_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_archived_idx ON public.users USING btree (archived);


--
-- Name: users_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_idx ON public.users USING btree (email) WHERE (archived = false);


--
-- Name: users_first_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_first_name_idx ON public.users USING gin (first_name public.gin_trgm_ops);


--
-- Name: users_last_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_last_name_idx ON public.users USING gin (last_name public.gin_trgm_ops);


--
-- Name: users_last_seen_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_last_seen_idx ON public.users USING btree (last_seen) WHERE (archived = false);


--
-- Name: users_my_library_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_my_library_idx ON public.users USING btree (my_library) WHERE (my_library IS NOT NULL);


--
-- Name: users_username_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_username_idx ON public.users USING gin (username public.gin_trgm_ops);


--
-- Name: webhook_logs_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX webhook_logs_hash_idx ON public.webhook_logs USING btree (hash) WHERE (handled = true);


--
-- Name: xsolla_subscriptions_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX xsolla_subscriptions_user_id_idx ON public.xsolla_subscriptions USING btree (user_id);


--
-- Name: licenses licenses_set_update_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER licenses_set_update_at BEFORE INSERT OR UPDATE ON public.licenses FOR EACH ROW EXECUTE FUNCTION public.trigger_set_timestamp();


--
-- Name: shop_codes shop_codes_set_update_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shop_codes_set_update_at BEFORE INSERT OR UPDATE ON public.shop_codes FOR EACH ROW EXECUTE FUNCTION public.trigger_set_timestamp();


--
-- Name: analytic_events analytic_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytic_events
    ADD CONSTRAINT analytic_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: article_artists article_artists_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_artists
    ADD CONSTRAINT article_artists_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: article_categories article_categories_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_categories
    ADD CONSTRAINT article_categories_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: article_categories article_categories_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_categories
    ADD CONSTRAINT article_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: article_releases article_releases_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_releases
    ADD CONSTRAINT article_releases_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: articles articles_cover_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_cover_file_id_fkey FOREIGN KEY (cover_file_id) REFERENCES public.files(id) ON DELETE SET NULL;


--
-- Name: articles articles_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: articles articles_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id);


--
-- Name: file_status file_status_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_status
    ADD CONSTRAINT file_status_file_id_fkey FOREIGN KEY (file_id) REFERENCES public.files(id) ON DELETE CASCADE;


--
-- Name: file_status file_status_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_status
    ADD CONSTRAINT file_status_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: gold_time_ranges gold_time_ranges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gold_time_ranges
    ADD CONSTRAINT gold_time_ranges_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: gold_unsub_survey_results gold_unsub_survey_results_sub_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gold_unsub_survey_results
    ADD CONSTRAINT gold_unsub_survey_results_sub_id_fkey FOREIGN KEY (sub_id) REFERENCES public.xsolla_subscriptions(id) ON DELETE CASCADE;


--
-- Name: homepage_slider_item homepage_slider_item_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider_item
    ADD CONSTRAINT homepage_slider_item_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id);


--
-- Name: homepage_slider_item homepage_slider_item_background_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider_item
    ADD CONSTRAINT homepage_slider_item_background_file_id_fkey FOREIGN KEY (background_file_id) REFERENCES public.files(id);


--
-- Name: homepage_slider_item homepage_slider_item_group_id_group_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider_item
    ADD CONSTRAINT homepage_slider_item_group_id_group_type_fkey FOREIGN KEY (group_id, group_type) REFERENCES public.homepage_slider_item(id, slider_type) ON DELETE CASCADE;


--
-- Name: homepage_slider_item homepage_slider_item_slider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider_item
    ADD CONSTRAINT homepage_slider_item_slider_id_fkey FOREIGN KEY (slider_id) REFERENCES public.homepage_slider(id) ON DELETE CASCADE;


--
-- Name: homepage_slider_item homepage_slider_item_video_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.homepage_slider_item
    ADD CONSTRAINT homepage_slider_item_video_file_id_fkey FOREIGN KEY (video_file_id) REFERENCES public.files(id);


--
-- Name: license_access_tokens license_access_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_access_tokens
    ADD CONSTRAINT license_access_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: license_time_ranges license_time_ranges_gold_time_range_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_time_ranges
    ADD CONSTRAINT license_time_ranges_gold_time_range_id_fkey FOREIGN KEY (gold_time_range_id) REFERENCES public.gold_time_ranges(id) ON DELETE CASCADE;


--
-- Name: license_time_ranges license_time_ranges_license_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.license_time_ranges
    ADD CONSTRAINT license_time_ranges_license_id_fkey FOREIGN KEY (license_id) REFERENCES public.licenses(id) ON DELETE CASCADE;


--
-- Name: licenses licenses_oauth_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.licenses
    ADD CONSTRAINT licenses_oauth_id_fkey FOREIGN KEY (oauth_id) REFERENCES public.license_access_tokens(id);


--
-- Name: licenses licenses_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.licenses
    ADD CONSTRAINT licenses_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: menu_items menu_items_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.menu_sections(id) ON DELETE CASCADE;


--
-- Name: menu_sections menu_sections_menu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_sections
    ADD CONSTRAINT menu_sections_menu_id_fkey FOREIGN KEY (menu_id) REFERENCES public.menus(id) ON DELETE CASCADE;


--
-- Name: mood_omitted_songs mood_omitted_songs_mood_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mood_omitted_songs
    ADD CONSTRAINT mood_omitted_songs_mood_id_fkey FOREIGN KEY (mood_id) REFERENCES public.moods(id) ON DELETE CASCADE;


--
-- Name: mood_params mood_params_mood_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mood_params
    ADD CONSTRAINT mood_params_mood_id_fkey FOREIGN KEY (mood_id) REFERENCES public.moods(id) ON DELETE CASCADE;


--
-- Name: moods moods_background_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moods
    ADD CONSTRAINT moods_background_file_id_fkey FOREIGN KEY (background_file_id) REFERENCES public.files(id) ON DELETE SET NULL;


--
-- Name: moods moods_tile_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.moods
    ADD CONSTRAINT moods_tile_file_id_fkey FOREIGN KEY (tile_file_id) REFERENCES public.files(id) ON DELETE SET NULL;


--
-- Name: paypal_payments paypal_payments_gold_time_range_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paypal_payments
    ADD CONSTRAINT paypal_payments_gold_time_range_id_fkey FOREIGN KEY (gold_time_range_id) REFERENCES public.gold_time_ranges(id) ON DELETE CASCADE;


--
-- Name: paypal_payments paypal_payments_paypal_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paypal_payments
    ADD CONSTRAINT paypal_payments_paypal_subscription_id_fkey FOREIGN KEY (paypal_subscription_id) REFERENCES public.paypal_subscriptions(id);


--
-- Name: paypal_subscriptions paypal_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paypal_subscriptions
    ADD CONSTRAINT paypal_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: playlist_items playlist_items_playlist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlist_items
    ADD CONSTRAINT playlist_items_playlist_id_fkey FOREIGN KEY (playlist_id) REFERENCES public.playlists(id) ON DELETE CASCADE;


--
-- Name: playlists playlists_background_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlists
    ADD CONSTRAINT playlists_background_file_id_fkey FOREIGN KEY (background_file_id) REFERENCES public.files(id) ON DELETE SET NULL;


--
-- Name: playlists playlists_tile_file_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlists
    ADD CONSTRAINT playlists_tile_file_id_fkey FOREIGN KEY (tile_file_id) REFERENCES public.files(id) ON DELETE SET NULL;


--
-- Name: playlists playlists_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playlists
    ADD CONSTRAINT playlists_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: podcast_stations podcast_stations_podcast_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.podcast_stations
    ADD CONSTRAINT podcast_stations_podcast_id_fkey FOREIGN KEY (podcast_id) REFERENCES public.podcasts(id) ON DELETE CASCADE;


--
-- Name: podcast_stations podcast_stations_territory_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.podcast_stations
    ADD CONSTRAINT podcast_stations_territory_id_fkey FOREIGN KEY (territory_id) REFERENCES public.territories(id) ON DELETE CASCADE;


--
-- Name: poll_options poll_options_poll_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT poll_options_poll_id_fkey FOREIGN KEY (poll_id) REFERENCES public.polls(id);


--
-- Name: poll_votes poll_votes_option_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_option_id_fkey FOREIGN KEY (option_id) REFERENCES public.poll_options(id);


--
-- Name: poll_votes poll_votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: shop_codes shop_codes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_codes
    ADD CONSTRAINT shop_codes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: social_access_tokens social_access_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_access_tokens
    ADD CONSTRAINT social_access_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: streamlabs_payments streamlabs_payments_gold_time_range_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streamlabs_payments
    ADD CONSTRAINT streamlabs_payments_gold_time_range_id_fkey FOREIGN KEY (gold_time_range_id) REFERENCES public.gold_time_ranges(id) ON DELETE CASCADE;


--
-- Name: streamlabs_payments streamlabs_payments_streamlabs_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streamlabs_payments
    ADD CONSTRAINT streamlabs_payments_streamlabs_subscription_id_fkey FOREIGN KEY (streamlabs_subscription_id) REFERENCES public.streamlabs_subscriptions(id) ON DELETE CASCADE;


--
-- Name: streamlabs_profiles streamlabs_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streamlabs_profiles
    ADD CONSTRAINT streamlabs_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: streamlabs_subscriptions streamlabs_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.streamlabs_subscriptions
    ADD CONSTRAINT streamlabs_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_features user_features_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_features
    ADD CONSTRAINT user_features_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_settings user_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_settings
    ADD CONSTRAINT user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_my_library_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_my_library_fkey FOREIGN KEY (my_library) REFERENCES public.playlists(id);


--
-- Name: xsolla_payments xsolla_payments_gold_time_range_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xsolla_payments
    ADD CONSTRAINT xsolla_payments_gold_time_range_id_fkey FOREIGN KEY (gold_time_range_id) REFERENCES public.gold_time_ranges(id) ON DELETE CASCADE;


--
-- Name: xsolla_payments xsolla_payments_xsolla_subscription_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xsolla_payments
    ADD CONSTRAINT xsolla_payments_xsolla_subscription_id_fkey FOREIGN KEY (xsolla_subscription_id) REFERENCES public.xsolla_subscriptions(id);


--
-- Name: xsolla_subscriptions xsolla_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xsolla_subscriptions
    ADD CONSTRAINT xsolla_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

