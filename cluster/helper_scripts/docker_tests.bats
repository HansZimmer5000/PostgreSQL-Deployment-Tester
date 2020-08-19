#!/usr/bin/env bats

source ./docker_helper.sh

@test "Testing extract_token" {
  expected_token="SWMTKN-1-2i8ohukidaywfkb6m27k5x7gfxbe5x249on5nojvzq2q5bd96d-bvm7g9evund9pbb2e2oss0360"
  token=$(extract_token "to join please this link: 
  docker swarm join --token $expected_token 192.168.1.40:2377")
  [ "$expected_token" == "$token" ]

  expected_token="$extract_token_failure_text"
  token=$(extract_token "docker swarm join --token")
  [ "$expected_token" == "$token" ]

  expected_token="$extract_token_failure_text"
  token=$(extract_token "docker swarm join")
  [ "$expected_token" == "$token" ]

  expected_token="$extract_token_failure_text"
  token=$(extract_token "")
  [ "$expected_token" == "$token" ]

  expected_token="SWMTKN-1-42wpzpzw6wei4js9yk6p94uxh1hor6pzudrr0r62h36vsowk7l-5ym2754bkajlgu29rswqng34d"
  token=$(extract_token "    docker swarm join --token $expected_token 192.168.1.40:2377")
  [ "$expected_token" == "$token" ]

  expected_token="SWMTKN-1-2i8ohukidaywfkb6m27k5x7gfxbe5x249on5nojvzq2q5bd96d-bvm7g9evund9pbb2e2oss0360"
  token=$(extract_token "to join please this link:     docker swarm join --token $expected_token 192.168.1.40:2377")
  [ "$expected_token" == "$token" ]
}
