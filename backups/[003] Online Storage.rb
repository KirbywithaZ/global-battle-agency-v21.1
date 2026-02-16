#===============================================================================
# Global Battle Agency / Online Trading
#===============================================================================

module GlobalBattleAgency
  API_URL = "https://global-battle-agency.kirbywithaz.workers.dev"

  def self.get_master_key
    # Correct for v21.1 - combines Name and the 32-bit ID
    return "#{$player.name}_#{$player.id}"
  end

  def self.upload_pokemon(slot = 0)
    pkmn = $player.party[slot]
    return pbMessage(_INTL("No Pokemon found in slot {1}!", slot + 1)) if !pkmn

    # Marshal DNA packing: converts the whole Pokemon object to a text string
    pokemon_dna = [Marshal.dump(pkmn)].pack("m0")

    payload = {
      "id"   => self.get_master_key,
      "data" => pokemon_dna
    }

    pbMessage(_INTL("Sending {1}'s data to the cloud...", pkmn.name))

    begin
      response = HTTPLite.post("#{API_URL}/save", payload)
      if response[:body] && response[:body].include?("OK")
        pbMessage(_INTL("Success! Your {1} is now stored globally.", pkmn.name))
      else
        pbMessage(_INTL("Connection successful, but the cloud is full!"))
      end
    rescue Exception => e
      echoln "GBA Error: #{e.message}"
      pbMessage(_INTL("Failed to connect to the GBA cloud."))
    end
  end
end
