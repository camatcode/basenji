defmodule BasenjiWeb.ComicsControllerTest do
  use BasenjiWeb.ConnCase

  alias Basenji.Comics
  alias BasenjiWeb.ComicsController

  @moduletag :capture_log

  doctest ComicsController

  test "create comic", %{conn: conn} do
    comic = build(:comic) |> Map.from_struct()
    conn = post(conn, ~p"/api/comics", comic)
    assert %{"data" => comic} = json_response(conn, 200)
    assert valid_comic?(comic)
  end

  test "get comic", %{conn: conn} do
    comic = insert(:comic)
    conn = get(conn, ~p"/api/comics/#{comic.id}", %{})

    assert %{"data" => comic} = json_response(conn, 200)
    assert valid_comic?(comic)
  end

  test "update comic", %{conn: conn} do
    comic = insert(:comic) |> Map.from_struct()
    changes = build(:comic) |> Map.from_struct()

    conn = patch(conn, ~p"/api/comics/#{comic.id}", changes)

    assert %{"data" => updated} = json_response(conn, 200)
    assert valid_comic?(updated)
    # changed
    assert updated["author"] == changes.author
    assert updated["description"] == changes.description
    assert updated["released_year"] == changes.released_year
    assert updated["title"] == changes.title

    # unchanged
    assert updated["format"] == "#{comic.format}"
    assert updated["id"] == comic.id
    assert updated["page_count"] == comic.page_count
  end

  test "delete comic", %{conn: conn} do
    comic = insert(:comic)
    conn = delete(conn, ~p"/api/comics/#{comic.id}", %{})

    assert %{"data" => deleted} = json_response(conn, 200)
    assert deleted["id"] == comic.id

    {:error, :not_found} = Comics.get_comic(comic.id)
  end

  describe "list search order" do
    test "lists comics", %{conn: conn} do
      insert_list(100, :comic)
      conn = get(conn, ~p"/api/comics", %{})

      assert %{"data" => comics} = json_response(conn, 200)
      refute Enum.empty?(comics)

      comics
      |> Enum.each(fn comic ->
        assert valid_comic?(comic)
      end)
    end

    test "order", %{conn: conn} do
      insert_list(10, :comic)

      [:title, :author, :description, :resource_location, :released_year, :page_count]
      |> Enum.each(fn order ->
        conn = get(conn, ~p"/api/comics", %{"order_by" => "#{order}"})
        assert %{"data" => comics} = json_response(conn, 200)
        refute Enum.empty?(comics)

        manual_sort =
          Enum.sort_by(
            comics,
            fn comic ->
              m = comic
              m["#{order}"]
            end,
            :asc
          )

        assert comics == manual_sort
      end)
    end

    test "search by", %{conn: conn} do
      comics = insert_list(10, :comic)

      Enum.each(comics, fn comic ->
        [:title, :author, :resource_location, :format, :released_year]
        |> Enum.each(fn search_term ->
          search_val = comic |> Map.from_struct() |> Map.get(search_term)
          conn = get(conn, ~p"/api/comics", %{"#{search_term}" => search_val})
          assert %{"data" => results} = json_response(conn, 200)
          refute Enum.empty?(results)
          [_result] = Enum.filter(results, fn c -> c["id"] == comic.id end)
        end)
      end)
    end

    test "search_by time", %{conn: conn} do
      insert_list(10, :comic)
      :timer.sleep(1000)
      dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      inserted = insert(:comic)
      # inserted_after
      conn = get(conn, ~p"/api/comics", %{"inserted_after" => "#{dt}"})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [_result] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
      # inserted_before
      conn = get(conn, ~p"/api/comics", %{"inserted_before" => "#{dt}"})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [] = Enum.filter(results, fn c -> c["id"] == inserted.id end)

      updated_dt = NaiveDateTime.utc_now()
      :timer.sleep(1000)
      {:ok, _updated} = Comics.update_comic(inserted, %{title: Faker.Lorem.sentence()})
      conn = get(conn, ~p"/api/comics", %{"updated_after" => "#{updated_dt}"})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [_result] = Enum.filter(results, fn c -> c["id"] == inserted.id end)

      conn = get(conn, ~p"/api/comics", %{"updated_before" => "#{updated_dt}"})
      assert %{"data" => results} = json_response(conn, 200)
      refute Enum.empty?(results)
      [] = Enum.filter(results, fn c -> c["id"] == inserted.id end)
    end

    test "generic search", %{conn: conn} do
      a =
        insert(:comic,
          title: "Baz and Peace",
          author: "Arthur Smith",
          description: "A thrilling murder mystery"
        )

      b =
        insert(:comic,
          title: "Of foo and bar, or On The 25-fold Path",
          author: "Jane Smith",
          description: "Her best romance novel"
        )

      c =
        insert(:comic,
          title: "Potion-seller's guide to the galaxy",
          author: "Sam Major",
          description: "25 chapters of dense reading"
        )

      [{"and", [a.id, b.id]}, {"or", [b.id, c.id]}, {"it", [a.id, b.id]}, {"25", [b.id, c.id]}]
      |> Enum.each(fn {term, expected} ->
        conn = get(conn, ~p"/api/comics", %{"search" => term, "order_by" => "title"})
        assert %{"data" => results} = json_response(conn, 200)
        assert expected == results |> Enum.map(fn c -> c["id"] end)
      end)
    end
  end

  defp valid_comic?(comic_json) do
    assert comic_json["id"]
    assert comic_json["author"]
    assert comic_json["description"]
    assert comic_json["format"]
    assert comic_json["page_count"]
    assert comic_json["inserted_at"]
    assert comic_json["page_count"]
    assert comic_json["released_year"]
    assert comic_json["resource_location"]
    assert comic_json["title"]
    assert comic_json["updated_at"]
    true
  end
end
