<template>
  <section class="card block">
    <h2 class="card-title">Droits des managers</h2>
    <div class="table-wrap">
      <table class="table">
        <thead>
          <tr>
            <th scope="col">Manager</th>
            <th v-for="column in columns" :key="column.key" scope="col" class="center">{{ column.label }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="right in rights" :key="right.id">
            <th scope="row">
              <span class="name">{{ right.name }}</span>
              <span class="team">{{ right.team }}</span>
            </th>
            <td v-for="column in columns" :key="column.key" class="center">
              <input
                class="check"
                type="checkbox"
                :checked="right[column.key]"
                :aria-label="`${right.name} : ${column.label}`"
                @change="setRight(right.id, column.key, $event.target.checked)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<script>
import { org, setRight } from '../../services/orgService'

export default {
  name: 'RightsTable',

  data() {
    return {
      columns: [
        { key: 'validate', label: 'Valider' },
        { key: 'correct', label: 'Corriger' },
        { key: 'publish', label: 'Publier le planning' },
      ],
    }
  },

  computed: {
    rights() {
      return org.rights
    },
  },

  methods: {
    setRight(id, key, value) {
      setRight(id, key, value)
    },
  },
}
</script>

<style scoped>
.block {
  padding: 22px 26px 12px;
}

.block .card-title {
  margin-bottom: 14px;
  font-size: 19px;
}

.table-wrap {
  overflow-x: auto;
}

.center {
  text-align: center;
}

.name {
  display: block;
  font-size: 16px;
  font-weight: 700;
}

.team {
  display: block;
  font-size: 14px;
  font-weight: 400;
  color: var(--text-muted);
}

.check {
  width: 22px;
  height: 22px;
  accent-color: var(--brand);
}
</style>
